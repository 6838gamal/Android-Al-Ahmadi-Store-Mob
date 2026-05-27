---
name: ShellRoute nested Scaffold drawer bug
description: In GoRouter ShellRoute apps, child pages with nested Scaffolds break the drawer button if they use Builder to get context for openDrawer().
---

# ShellRoute nested Scaffold drawer bug

## The Rule
Never use `Builder(builder: (ctx) => IconButton(onPressed: () => Scaffold.of(ctx).openDrawer()))` inside a page that has its own nested `Scaffold`. Use `Scaffold.of(context)` where `context` is the `build(BuildContext context)` parameter directly.

**Why:** `Scaffold.of(ctx)` where `ctx` comes from a `Builder` inside the page's own `Scaffold` body will find the *inner* Scaffold (which has no drawer). The `context` from `build(BuildContext context)` is the widget element's own context — it sits *above* the Scaffold returned by `build()` — so `Scaffold.of(context)` correctly traverses UP past the inner Scaffold and finds the shell's outer Scaffold (which has the drawer).

**How to apply:** For any page inside a `ShellRoute` that needs to open the outer drawer, use:
```dart
leading: IconButton(
  icon: const Icon(Icons.menu, color: Colors.white),
  onPressed: () => Scaffold.of(context).openDrawer(),
),
```
No `Builder` wrapper needed. This applies to both `StatelessWidget` and `ConsumerStatefulWidget` pages. Also applies to `AppBar` and `SliverAppBar` leading widgets.

Pages that don't have a menu button at all (no `leading:` set) will show no way to open the drawer — add `leading:` explicitly to every shell child page's AppBar.
