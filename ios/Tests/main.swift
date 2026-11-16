import CoreGraphics
import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

do {
    let viewport = CGSize(width: 300, height: 300)
    let landscape = CGSize(width: 1200, height: 600)
    let portrait = CGSize(width: 600, height: 1200)
    check(AvatarCropGeometry.minimumZoom(image: landscape, viewport: viewport) == 0.5, "Landscape must fill crop height")
    check(AvatarCropGeometry.minimumZoom(image: portrait, viewport: viewport) == 0.5, "Portrait must fill crop width")
    check(AvatarCropGeometry.centeredOffset(image: landscape, viewport: viewport, zoom: 0.5) == CGPoint(x: 150, y: 0), "Center landscape horizontally")
    check(AvatarCropGeometry.centeredOffset(image: portrait, viewport: viewport, zoom: 0.5) == CGPoint(x: 0, y: 150), "Center portrait vertically")
    let centered = AvatarCropGeometry.drawingRect(image: landscape, viewport: viewport, zoom: 0.5, offset: CGPoint(x: 150, y: 0), outputSide: 512)
    check(centered == CGRect(x: -256, y: 0, width: 1024, height: 512), "Export must match the centered viewport")
    let zoomed = AvatarCropGeometry.drawingRect(image: landscape, viewport: viewport, zoom: 1, offset: CGPoint(x: 600, y: 100), outputSide: 512)
    check(abs(zoomed.minX + 1024) < 0.001 && abs(zoomed.width - 2048) < 0.001, "Export must preserve zoom and pan")
}

let suite = "fake-chat.tests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let persistence = ChatPersistence(defaults: defaults)
let store = ChatStore(persistence: persistence)
check(store.characters.isEmpty && store.conversations.isEmpty && store.current == nil, "Fresh install must be empty")
check(store.conversations(for: .weChat).isEmpty, "No current character must produce no conversations")
store.addCharacter(name: "  ")
check(store.characters.isEmpty, "Blank names must be rejected")
let avatar = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zl1sAAAAASUVORK5CYII=")!
store.addCharacter(name: " Alice ", avatarData: avatar)
let alice = store.characters[0]
check(store.currentID == alice.id && alice.name == "Alice", "First character must be selected")
check(store.start(with: alice, platform: .weChat) == nil, "Self conversations must be rejected")
store.addCharacter(name: "Bob")
let bob = store.characters[1]
check(store.currentID == alice.id, "Creating another character must preserve selection")
let id = store.start(with: bob, platform: .weChat)!
check(store.start(with: bob, platform: .weChat) == id, "Reuse an existing conversation")
store.send("Hello", to: id)
store.select(bob)
store.send("Hi", to: id)
store.send(" \n ", to: id)
check(store.conversations[0].messages.map(\.senderID) == [alice.id, bob.id], "Both participants must be able to send; blank messages must be rejected")
let restored = ChatStore(persistence: persistence)
check(restored.currentID == bob.id && restored.characters.count == 2, "Restore characters and current identity")
check(restored.characters[0].avatarData == avatar, "Persist uploaded avatar bytes")
check(restored.conversations[0].messages.map(\.text) == ["Hello", "Hi"], "Restore message text and order")
check(restored.conversations(for: .weChat).count == 1, "Filter conversations by platform and identity")

let replacementAvatar = Data([1, 2, 3, 4])
restored.updateCharacter(alice.id, name: "Alice updated", avatarData: replacementAvatar, signature: "Hello 世界 🌿")
let edited = ChatStore(persistence: persistence)
check(edited.characters[0].signature == "Hello 世界 🌿", "Persist signature with avatar and name")
check(edited.characters[0].name == "Alice updated" && edited.characters[0].avatarData == replacementAvatar, "Persist edits to an existing avatar")
check(edited.currentID == bob.id && edited.conversations[0].messages.count == 2, "Avatar editing must preserve identity and conversations")
restored.updateCharacter(alice.id, name: "   ", avatarData: nil)
check(restored.characters[0].avatarData == replacementAvatar, "Invalid edits must not clear an avatar")

restored.updateCharacter(alice.id, name: "Alice updated", avatarData: replacementAvatar)
check(restored.characters[0].signature == "Hello 世界 🌿", "Editing other fields must preserve signature")
restored.updateCharacter(alice.id, name: "Alice updated", avatarData: replacementAvatar, signature: "")
check(ChatStore(persistence: persistence).characters[0].signature.isEmpty, "Allow clearing a signature")

let state = try persistence.load()!
let encoded = try JSONEncoder().encode(state)
var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
var legacyCharacters = legacy["characters"] as! [[String: Any]]
for index in legacyCharacters.indices {
    legacyCharacters[index].removeValue(forKey: "avatarData")
    legacyCharacters[index].removeValue(forKey: "signature")
    legacyCharacters[index]["symbol"] = "person.fill"
    legacyCharacters[index]["tint"] = 0
}
legacy["characters"] = legacyCharacters
var conversations = legacy["conversations"] as! [[String: Any]]
conversations[0].removeValue(forKey: "platform")
conversations[0].removeValue(forKey: "deletedForCharacterIDs")
conversations[0].removeValue(forKey: "clearedMessageCounts")
legacy["conversations"] = conversations
defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "fake-chat.state.v1")
let migrated = ChatStore(persistence: persistence)
check(migrated.error == nil && migrated.conversations[0].platform == .weChat, "Legacy records must default to WeChat")
check(migrated.characters.count == 2 && migrated.characters[0].avatarData == nil, "Legacy vector avatars must migrate to an empty photo without losing characters")
check(migrated.characters[0].signature.isEmpty, "Legacy profiles must default to an empty signature")
check(migrated.conversations[0].id == id && migrated.currentID == bob.id, "Legacy IDs and selection must be preserved")

legacy["currentID"] = UUID().uuidString
defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "fake-chat.state.v1")
let repaired = ChatStore(persistence: persistence)
check(repaired.currentID == alice.id, "Invalid selection must recover to an existing character")

restored.addCharacter(name: "Charlie")
let charlie = restored.characters[2]
restored.select(alice)
let retainedID = restored.start(with: charlie, platform: .weChat)!
restored.send("Keep this", to: retainedID)
restored.select(bob)
restored.deleteCharacter(bob.id)
check(restored.currentID == alice.id, "Deleting current character must select a remaining character")
check(restored.conversations.count == 1 && restored.conversations[0].id == retainedID, "Delete associated chats and preserve unrelated chats")
let afterDeletion = ChatStore(persistence: persistence)
check(afterDeletion.characters.count == 2 && afterDeletion.currentID == alice.id, "Persist character deletion and selection")
check(afterDeletion.conversations[0].messages[0].text == "Keep this", "Preserve unrelated messages after reload")
restored.deleteCharacter(charlie.id)
check(restored.currentID == alice.id && restored.conversations.isEmpty, "Deleting another character must preserve current selection")
restored.deleteCharacter(alice.id)
check(restored.characters.isEmpty && restored.currentID == nil, "Deleting final character must return to empty state")
let emptyReload = ChatStore(persistence: persistence)
check(emptyReload.characters.isEmpty && emptyReload.currentID == nil && emptyReload.conversations.isEmpty, "Persist empty state after deletion")
restored.deleteCharacter(UUID())
check(restored.characters.isEmpty, "Deleting unknown character must be harmless")

do {
    let deletionSuite = "fake-chat.conversation-deletion.\(UUID().uuidString)"
    let deletionDefaults = UserDefaults(suiteName: deletionSuite)!
    defer { deletionDefaults.removePersistentDomain(forName: deletionSuite) }
    let persistence = ChatPersistence(defaults: deletionDefaults)
    let chats = ChatStore(persistence: persistence)
    chats.addCharacter(name: "A")
    chats.addCharacter(name: "B")
    chats.addCharacter(name: "C")
    let a = chats.characters[0], b = chats.characters[1], c = chats.characters[2]
    let id = chats.start(with: b, platform: .weChat)!
    let unrelated = chats.start(with: c, platform: .weChat)!
    chats.send("Old A", to: id)
    chats.select(b)
    chats.send("Old B", to: id)
    chats.select(a)
    chats.deleteConversation(id)
    check(chats.conversations(for: .weChat).map(\.id) == [unrelated], "Only delete the selected conversation from the current list")
    let reloaded = ChatStore(persistence: persistence)
    check(!reloaded.conversations(for: .weChat).contains { $0.id == id }, "Persist per-character deletion")
    reloaded.select(b)
    check(reloaded.conversations(for: .weChat).contains { $0.id == id }, "Other participant must keep the conversation")
    check(reloaded.messages(in: reloaded.conversations.first { $0.id == id }!).map(\.text) == ["Old A", "Old B"], "Other participant must keep complete history")
    reloaded.select(c)
    reloaded.deleteConversation(id)
    reloaded.select(a)
    check(reloaded.start(with: b, platform: .weChat) == id, "Reopen the shared conversation without duplicating it")
    check(reloaded.messages(in: reloaded.conversations.first { $0.id == id }!).isEmpty, "Reopening must not restore deleted history")
    reloaded.send("New A", to: id)
    reloaded.select(b)
    check(reloaded.messages(in: reloaded.conversations.first { $0.id == id }!).map(\.text) == ["Old A", "Old B", "New A"], "Other participant sees original history and new messages")
    reloaded.deleteConversation(id)
    reloaded.select(a)
    reloaded.deleteConversation(id)
    reloaded.start(with: b, platform: .weChat).map { reloaded.send("Fresh", to: $0) }
    reloaded.select(b)
    check(reloaded.conversations(for: .weChat).contains { $0.id == id }, "New message makes the conversation visible again")
    check(reloaded.messages(in: reloaded.conversations.first { $0.id == id }!).map(\.text) == ["Fresh"], "New message must not restore deleted history for either side")
    let final = ChatStore(persistence: persistence)
    check(final.messages(in: final.conversations.first { $0.id == id }!).map(\.text) == ["Fresh"], "Persist independent history cutoffs")
}

do {
    let photoDefaults = UserDefaults(suiteName: "fake-chat.photos.\(UUID().uuidString)")!
    let persistence = ChatPersistence(defaults: photoDefaults)
    let chats = ChatStore(persistence: persistence)
    chats.addCharacter(name: "A")
    chats.addCharacter(name: "B")
    let sender = chats.characters[0], recipient = chats.characters[1]
    let id = chats.start(with: recipient, platform: .weChat)!
    chats.send("Text", to: id)
    chats.sendPhoto(avatar, to: id, senderID: sender.id)
    chats.sendPhoto(Data(), to: id, senderID: sender.id)
    chats.sendPhoto(avatar, to: id, senderID: UUID())
    let reloaded = ChatStore(persistence: persistence)
    let messages = reloaded.conversations[0].messages
    check(messages.count == 2, "Reject empty photos and unknown senders")
    check(messages[0].text == "Text" && messages[0].photoData == nil, "Text records remain compatible")
    check(messages[1].photoData == avatar && messages[1].senderID == sender.id, "Persist photo bytes and sender")
    let orderedPhotos = [Data([3]), Data([1]), Data([2])]
    chats.sendPhotos(orderedPhotos, to: id, senderID: sender.id)
    let batch = ChatStore(persistence: persistence).conversations[0].messages.suffix(3)
    check(batch.compactMap(\.photoData) == orderedPhotos, "Photo batches must preserve selection order after reload")
    photoDefaults.removeObject(forKey: "fake-chat.state.v1")
}

let corrupted = Data("invalid data".utf8)
defaults.set(corrupted, forKey: "fake-chat.state.v1")
let damaged = ChatStore(persistence: persistence)
damaged.addCharacter(name: "New")
check(damaged.error != nil && defaults.data(forKey: "fake-chat.state.v1") == corrupted, "Failed loads must preserve original data")
print("Passed: empty state, character creation, conversation flow, persistence, legacy migration, character deletion, per-character conversation deletion, and data preservation")
