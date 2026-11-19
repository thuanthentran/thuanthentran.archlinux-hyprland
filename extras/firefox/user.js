// Firefox prefs applied on every start (overrides about:config). setup.sh dotfiles links
// this file into each Firefox profile; edit here, then restart Firefox.

// Touchpad: keep gliding after the fingers lift (kinetic scrolling on Wayland).
user_pref("apz.gtk.kinetic_scroll.enabled", true);
// How fast the glide slows down. Default 0.002; lower = longer glide, higher = stops sooner.
user_pref("apz.fling_friction", "0.0015");

// Mouse wheel: physics-based smooth scrolling, so each notch eases out instead of jumping.
user_pref("general.smoothScroll", true);
user_pref("general.smoothScroll.msdPhysics.enabled", true);
// Wheel speed in percent (100 = default). Raise for faster, lower for slower.
user_pref("mousewheel.default.delta_multiplier_y", 100);
