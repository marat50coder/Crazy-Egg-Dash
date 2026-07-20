/// Central registry of every image asset used by the game.
///
/// Keeping the paths in one place avoids typos scattered across the codebase
/// and makes it trivial to see what art the game relies on.
class Assets {
  Assets._();

  static const String _base = 'assets/';

  // ---- Loading screens ----
  static const String loadingHorizontal = '${_base}Horizontal_Loading.webp';
  static const String loadingVertical = '${_base}Vertical_Loading.webp';

  // ---- Menu / UI background ----
  static const String menuBg = '${_base}Bg_Menu.webp';

  // ---- Running ground / floor texture ----
  static const String floor = '${_base}floor_grass.webp';

  // ---- Power-up crate (grants a super-ability when grabbed) ----
  static const String magicBox = '${_base}magic_box.webp';

  // ---- App icon (used inside menus / about) ----
  static const String icon = '${_base}icon.png';

  // Single representative chicken sprite (handy where a const path is needed).
  static const String chickenIdle3 = '${_base}chicken3.webp';

  // ---- Chicken species (standing pose, used in menus & in the flock) ----
  static const List<String> chickenIdle = [
    '${_base}chicken1.webp',
    '${_base}chicken2.webp',
    '${_base}chicken3.webp',
    '${_base}chicken4.webp',
  ];

  // ---- Chicken species (running pose, used while dashing) ----
  static const List<String> chickenRun = [
    '${_base}chicken_run1.webp',
    '${_base}chicken_run2.webp',
    '${_base}chicken_run3.webp',
    '${_base}chicken_run4.webp',
  ];

  // ---- Chicken species (jumping pose) ----
  static const List<String> chickenJump = [
    '${_base}chicken_jump1.webp',
    '${_base}chicken_jump2.webp',
    '${_base}chicken_jump3.webp',
    '${_base}chicken_jump4.webp',
  ];

  // ---- Eggs ----
  static const String egg = '${_base}egg_asset.webp';
  static const String eggs = '${_base}eggs_asset.webp';
  static const String goldenEgg = '${_base}golden_egg_asset.webp';
  static const String speckledEgg = '${_base}speckled egg_assets.webp';
  static const String brokenEggs = '${_base}broken_eggs.webp';
  static const String egg1kg = '${_base}1kg_egg_asset.webp';
  static const String egg3kg = '${_base}3kg_egg_asset.webp';
  static const String egg5kg = '${_base}5kg_egg_asset.webp';

  // ---- Backgrounds (cycled during a run) ----
  static const List<String> backgrounds = [
    '${_base}bg1.webp',
    '${_base}bg2.webp',
    '${_base}bg3.webp',
    '${_base}bg4.webp',
    '${_base}bg5.webp',
  ];
  static const String cloud = '${_base}cloud_asset.webp';

  // ---- Obstacles / props ----
  static const String rock = '${_base}rock_asset.webp';
  static const String rockPlatform = '${_base}rock_platform_asset.webp';
  static const String platform = '${_base}platform_asset.webp';
  static const String floatingPlatform =
      '${_base}floating_wooden_platform_asset.webp';
  static const String log = '${_base}hollow_fallen_log_asset.webp';
  static const String bush = '${_base}bush_asset.webp';
  static const String tree = '${_base}tree_asset.webp';
  static const String treeStump = '${_base}tree_stump_asset.webp';
  static const String finish = '${_base}finish_asset.webp';
  static const String arrow = '${_base}arrow_asset.webp';

  // ---- Currencies / collectibles ----
  static const String coin = '${_base}coin_asset.webp';
  static const String feather = '${_base}coin_feather_asset.webp';
  static const String crystal = '${_base}crystal_asset.webp';
  static const String blueCrystal = '${_base}blue_crystal_asset.webp';
  static const String scales = '${_base}scales_asset.webp';

  /// Every image that should be pre-decoded during the loading screen so the
  /// first frame of gameplay is smooth.
  static List<String> get preloadList => [
        ...chickenIdle,
        ...chickenRun,
        ...chickenJump,
        ...backgrounds,
        magicBox,
        egg,
        goldenEgg,
        speckledEgg,
        brokenEggs,
        eggs,
        cloud,
        rock,
        treeStump,
        log,
        bush,
        tree,
        platform,
        floatingPlatform,
        finish,
        coin,
        feather,
        crystal,
        blueCrystal,
        scales,
        icon,
      ];
}
