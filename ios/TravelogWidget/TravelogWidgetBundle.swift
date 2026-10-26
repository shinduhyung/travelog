import SwiftUI
import WidgetKit

// Must match HomeWidgetService.iOSAppGroupId on the Dart side.
private let appGroupId = "group.com.ahnlee.travellog"

struct SnapshotEntry: TimelineEntry {
  let date: Date
  let image: UIImage?
}

// Reads the PNG path the app saved under `imageKey` via home_widget.
struct SnapshotProvider: TimelineProvider {
  let imageKey: String

  func placeholder(in context: Context) -> SnapshotEntry {
    SnapshotEntry(date: Date(), image: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
    // The app reloads the timeline whenever it saves a new image.
    completion(Timeline(entries: [loadEntry()], policy: .never))
  }

  private func loadEntry() -> SnapshotEntry {
    let defaults = UserDefaults(suiteName: appGroupId)
    let image = defaults?.string(forKey: imageKey).flatMap { UIImage(contentsOfFile: $0) }
    return SnapshotEntry(date: Date(), image: image)
  }
}

struct SnapshotView: View {
  let entry: SnapshotEntry

  var body: some View {
    content.widgetBackground(Color.white)
  }

  @ViewBuilder
  private var content: some View {
    if let image = entry.image {
      Image(uiImage: image)
        .resizable()
        .aspectRatio(contentMode: .fit)
    } else {
      VStack(spacing: 8) {
        Image("AppLogo")
          .resizable()
          .frame(width: 56, height: 56)
          .clipShape(RoundedRectangle(cornerRadius: 12))
        Text("Open Travelog to update")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }
}

extension View {
  @ViewBuilder
  func widgetBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(color, for: .widget)
    } else {
      background(color)
    }
  }
}

struct TravelogWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TravelogWidget", provider: SnapshotProvider(imageKey: "filename")) { entry in
      SnapshotView(entry: entry)
    }
    .configurationDisplayName("Travelog Countries")
    .description("Your visited countries map.")
    .supportedFamilies([.systemMedium, .systemLarge])
    .contentMarginsDisabledIfAvailable()
  }
}

struct TravelogCitiesWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TravelogCitiesWidget", provider: SnapshotProvider(imageKey: "cities_filename")) { entry in
      SnapshotView(entry: entry)
    }
    .configurationDisplayName("Travelog Cities")
    .description("Your visited cities map.")
    .supportedFamilies([.systemMedium, .systemLarge])
    .contentMarginsDisabledIfAvailable()
  }
}

extension WidgetConfiguration {
  func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 17.0, *) {
      return contentMarginsDisabled()
    }
    return self
  }
}

@main
struct TravelogWidgetBundle: WidgetBundle {
  var body: some Widget {
    TravelogWidget()
    TravelogCitiesWidget()
  }
}
