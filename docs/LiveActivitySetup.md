# Live Activity + Widget setup

Adding a widget/Live Activity requires a new **Widget Extension target**, which
must be created through Xcode's wizard (hand-editing project.pbxproj for a new
target is error-prone and easy to corrupt). Everything else is prepared below —
after the wizard, it's paste-and-build.

## 1. Create the target (Xcode, ~1 minute)

1. File → New → Target… → **Widget Extension**
2. Product name: `CircleRunWidgets`
3. Check **Include Live Activity**, uncheck "Include Configuration App Intent"
4. Activate the scheme when prompted.

## 2. App ↔ extension shared attributes

Create `RunActivityAttributes.swift` and add it to **both** the app target and
the widget target (File Inspector → Target Membership):

```swift
import ActivityKit

struct RunActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Double
        var miles: Double
        var pace: String        // "9'41\""
        var isPaused: Bool
    }
    var routeName: String
    var targetMiles: Double
}
```

## 3. Live Activity UI (replace the wizard's generated LiveActivity file)

```swift
import WidgetKit
import SwiftUI
import ActivityKit

struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            // Lock screen
            HStack {
                VStack(alignment: .leading) {
                    Text(context.attributes.routeName).font(.headline)
                    Text(String(format: "%.2f mi", context.state.miles))
                        .font(.title2.bold()).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(context.state.pace + " /mi").monospacedDigit()
                    Text(Duration.seconds(context.state.elapsedSeconds),
                         format: .time(pattern: .minuteSecond))
                        .font(.title2.bold()).monospacedDigit()
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(String(format: "%.2f mi", context.state.miles)).bold()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.pace).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.routeName).font(.caption)
                }
            } compactLeading: {
                Image(systemName: "figure.run")
            } compactTrailing: {
                Text(String(format: "%.1f", context.state.miles)).monospacedDigit()
            } minimal: {
                Image(systemName: "figure.run")
            }
        }
    }
}
```

## 4. Start/update/end from NavigationManager (app target)

```swift
import ActivityKit

private var runActivity: Activity<RunActivityAttributes>?

// in startNavigation(for:)
let attributes = RunActivityAttributes(routeName: route.name, targetMiles: route.distance)
runActivity = try? Activity.request(
    attributes: attributes,
    content: .init(state: .init(elapsedSeconds: 0, miles: 0, pace: "0'00\"", isPaused: false),
                   staleDate: nil))

// in updateStats()
Task {
    await runActivity?.update(.init(
        state: .init(elapsedSeconds: elapsedSeconds,
                     miles: distanceTraveled / 1609.34,
                     pace: runningStats.currentPace,
                     isPaused: runningStats.isPaused),
        staleDate: nil))
}

// in stopNavigation()
Task { await runActivity?.end(nil, dismissalPolicy: .immediate) }
```

## 5. Info.plist key (app target)

Build Settings → add `INFOPLIST_KEY_NSSupportsLiveActivities = YES`
(or add `NSSupportsLiveActivities` = YES to CircleRun/Info.plist).

## Home-screen "Generate a loop" widget (optional, same target)

A `StaticConfiguration` widget whose view deep-links via
`.widgetURL(URL(string: "circlerun://generate"))`; handle the URL in
CircleRunApp with `.onOpenURL` to open the distance sheet. Requires
registering the `circlerun` URL scheme in Info.plist.
