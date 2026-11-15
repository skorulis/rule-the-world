# Architecture
This document records the architectural decisions behind this app.

---

## 1. Use SwiftUI for all UI presentation

Unless a feature can only be built using UIKit, all code should be pure SwiftUI.

---

## 2. Coordinator-based navigation (ASKCoordinator)

- Navigation is driven by [ASKCoordinator](https://github.com/skorulis/ASKCoordinator). Screens are described by `CoordinatorPath` enums (`Scene/Coordinator/MainPath.swift`) and rendered by `CoordinatorPathRenderer` types (`Scene/Coordinator/MainPathRenderer.swift`). The root view is a `CoordinatorView`.
- Renderers are resolved from the DI container (`resolver.mainPathRenderer()`), so adding a path usually means touching `MainPath`, the renderer, and the assembly.

---

## 3. Dependency injection with Knit

- Dependencies are provided by [Knit](https://github.com/skorulis/ASKKnit) (Swinject-based, compile-time safe). There is one module assembly (`Service/App/*Assembly.swift`) which first assembles `ASKCoreAssembly` and then registers app services and view models. The `KnitBuildPlugin` generates type-safe resolver extensions from the assembly listed in `knitconfig.json`.
- View model initializers are marked `@Resolvable` so Knit can generate factory wiring; each view model is registered in `registerViewModels(container:)`.
- `knitconfig.json` must be part of the Xcode project (not just on disk) or the build plugin will not find it. A first successful build may be needed before generated symbols appear.
- Do not reach for singletons or global state; inject through the resolver instead.

---

## 4. Folder layout by responsibility

Sources are grouped by responsibility, not by feature screen:

| Folder | Contents |
|--------|----------|
| `Scene/` | SwiftUI views and their view models, grouped by feature (`Scene/App`, `Scene/Coordinator`, ...) |
| `Model/` | Plain data types and domain models |
| `Service/` | Business logic, API clients, and the Knit assembly (`Service/App`) |
| `Store/` | Persistence (UserDefaults, files, databases) |
| `DesignSystem/` | Reusable, presentational UI components |
| `Util/` | Small cross-cutting helpers |
| `Resource/` | Asset catalogs, fonts, and SwiftGen output |

---

## 5. View models own screen state; views are thin

- Each screen has a view model declared with `@Observable`, owned by the view via `@State`. Anything a view displays or binds is exposed as a `var` property (stored or computed). Methods are reserved for actions (user intents, navigation, async work).
- Views should not call functions just to *read* state (`func title() -> String` is a smell). Async work and navigation requests belong in the view model, not in `.task`/`.onAppear` closures that contain logic.

---

## 6. DesignSystem components are presentational

- Views in `DesignSystem/` take parameters and bindings only. They never own a view model, and every component ships with a `#Preview`.

---

## 7. Testing

- Tests should be created using Swift Testing instead of XCTest.
---

## 8. Hex grid uses H3

- The territory grid is [Uber H3](https://h3geo.org) via the `SwiftyH3` Swift package (`HexGridService` is the only type that imports it). A cell's `UInt64` index is its stable identity (`Model/Hex/HexCell`); persistence stores those raw values so the model never depends on the library type.
- Base resolution is 9 (~0.105 km² per hex). Zoomed-out views switch to a coarser resolution chosen by `HexZoomPolicy` so the visible tile count stays within a ~400 tile budget; ownership is aggregated to coarser cells by majority vote (`HexOwnershipStore.aggregated(at:)`).
