import Foundation
import EventKit
import Combine

class CalendarEventManager: ObservableObject {
    static let shared = CalendarEventManager()
    private let eventStore = EKEventStore()
    
    @Published var todaysEvents: [EKEvent] = []
    @Published var hasAccess: Bool = false
    
    init() {
        checkAccess()
        NotificationCenter.default.addObserver(self, selector: #selector(eventStoreChanged), name: .EKEventStoreChanged, object: eventStore)
    }
    
    @objc private func eventStoreChanged() {
        if hasAccess {
            fetchTodaysEvents()
        }
    }
    
    func checkAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        self.hasAccess = (status == .authorized || status == .fullAccess)
    }
    
    func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    self.hasAccess = granted
                    completion(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    self.hasAccess = granted
                    completion(granted)
                }
            }
        }
    }
    
    func fetchTodaysEvents() {
        guard hasAccess else { return }
        
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.startOfDay(for: today)
        guard let endDate = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startDate) else { return }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        var events = eventStore.events(matching: predicate)
        
        // Filter out all-day events if preferred, or sort them
        events.sort { $0.startDate < $1.startDate }
        
        DispatchQueue.main.async {
            self.todaysEvents = events
        }
    }
}
