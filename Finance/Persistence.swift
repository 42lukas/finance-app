//
//  Persistence.swift
//  Finance
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.id = UUID()
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer
    let usesSharedStore: Bool

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Finance")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            usesSharedStore = false
        } else {
            let configuration = Self.storeConfiguration(for: container.managedObjectModel)
            container.persistentStoreDescriptions.first!.url = configuration.url
            usesSharedStore = configuration.usesSharedStore
        }

        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        let loadedContainer = container
        let shouldPrepareSharedStore = !inMemory && usesSharedStore

        loadedContainer.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }

            guard shouldPrepareSharedStore else { return }
            Self.backfillStableIdentifiers(in: loadedContainer) {
                EvenSharedStore.markReady()
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func refreshViewContextFromSharedStore() {
        let context = container.viewContext
        context.perform {
            guard !context.hasChanges else { return }
            // Keep existing Item references attached to the context. Views such as the
            // edit sheet hold those references while a widget update may arrive.
            context.refreshAllObjects()
        }
    }

    private static var isWidgetExtension: Bool {
        Bundle.main.bundleURL.pathExtension == "appex"
    }

    private static func storeConfiguration(
        for model: NSManagedObjectModel
    ) -> (url: URL, usesSharedStore: Bool) {
        let legacyURL = NSPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent(EvenSharedStore.storeFileName)

        guard let sharedURL = EvenSharedStore.storeURL else {
            return (legacyURL, false)
        }

        if isWidgetExtension {
            guard EvenSharedStore.isReady else {
                return (URL(fileURLWithPath: "/dev/null"), false)
            }
            return (sharedURL, true)
        }

        guard !FileManager.default.fileExists(atPath: sharedURL.path) else {
            return (sharedURL, true)
        }

        guard FileManager.default.fileExists(atPath: legacyURL.path) else {
            return (sharedURL, true)
        }

        do {
            try migrateStore(from: legacyURL, to: sharedURL, model: model)
            return (sharedURL, true)
        } catch {
            // Keep using the legacy store if migration fails, so existing data stays accessible.
            print("Gemeinsamer Datenspeicher konnte nicht vorbereitet werden: \(error.localizedDescription)")
            return (legacyURL, false)
        }
    }

    private static func migrateStore(
        from sourceURL: URL,
        to destinationURL: URL,
        model: NSManagedObjectModel
    ) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: sourceURL,
            options: options
        )

        try coordinator.migratePersistentStore(
            store,
            to: destinationURL,
            options: options,
            withType: NSSQLiteStoreType
        )
    }

    private static func backfillStableIdentifiers(
        in container: NSPersistentContainer,
        completion: @escaping () -> Void
    ) {
        container.performBackgroundTask { context in
            let request: NSFetchRequest<Item> = Item.fetchRequest()
            request.predicate = NSPredicate(format: "id == nil")

            do {
                let items = try context.fetch(request)
                items.forEach { $0.id = UUID() }
                if context.hasChanges {
                    try context.save()
                }
                completion()
            } catch {
                print("Eintrags-IDs konnten nicht ergänzt werden: \(error.localizedDescription)")
            }
        }
    }
}
