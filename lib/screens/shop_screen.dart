import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assets.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

enum _PayWith { coins, feathers, crystals }

class _ShopItem {
  const _ShopItem({
    required this.title,
    required this.icon,
    required this.payWith,
    required this.price,
    this.coins = 0,
    this.eggs = 0,
    this.feathers = 0,
  });
  final String title;
  final String icon;
  final _PayWith payWith;
  final int price;
  final int coins;
  final int eggs;
  final int feathers;
}

/// Screen #11 — trade currencies for packs of eggs, coins and premium goods.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  static const List<_ShopItem> _items = [
    _ShopItem(
        title: 'Egg Basket',
        icon: Assets.eggs,
        payWith: _PayWith.coins,
        price: 550,
        eggs: 12),
    _ShopItem(
        title: 'Big Egg Crate',
        icon: Assets.egg3kg,
        payWith: _PayWith.coins,
        price: 1600,
        eggs: 40),
    _ShopItem(
        title: 'Feather Pouch',
        icon: Assets.feather,
        payWith: _PayWith.crystals,
        price: 1,
        feathers: 10),
    _ShopItem(
        title: 'Coin Chest',
        icon: Assets.coin,
        payWith: _PayWith.feathers,
        price: 6,
        coins: 1200),
    _ShopItem(
        title: 'Golden Bundle',
        icon: Assets.goldenEgg,
        payWith: _PayWith.crystals,
        price: 3,
        eggs: 30,
        coins: 800),
    _ShopItem(
        title: 'Starter Pack',
        icon: Assets.egg5kg,
        payWith: _PayWith.coins,
        price: 950,
        eggs: 20,
        feathers: 3),
  ];

  String _priceLabel(_ShopItem item) => '${item.price}';
  String _priceIcon(_ShopItem item) => switch (item.payWith) {
        _PayWith.coins => Assets.coin,
        _PayWith.feathers => Assets.feather,
        _PayWith.crystals => Assets.crystal,
      };

  bool _canAfford(GameState gs, _ShopItem item) => switch (item.payWith) {
        _PayWith.coins => gs.coins >= item.price,
        _PayWith.feathers => gs.feathers >= item.price,
        _PayWith.crystals => gs.crystals >= item.price,
      };

  void _buy(BuildContext context, GameState gs, _ShopItem item) {
    bool ok;
    switch (item.payWith) {
      case _PayWith.coins:
        ok = gs.spendCoins(item.price);
        break;
      case _PayWith.feathers:
        ok = gs.spendFeathers(item.price);
        break;
      case _PayWith.crystals:
        ok = gs.spendCrystals(item.price);
        break;
    }
    if (!ok) return;
    AudioManager.instance.play(Sfx.reward);
    gs.grantPack(
      coins: item.coins,
      eggs: item.eggs,
      feathers: item.feathers,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 900),
        backgroundColor: AppColors.grassGreen,
        content: Text('Purchased ${item.title}!',
            style: AppText.body(15, color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return SkyScaffold(
      title: 'Shop',
      onBack: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: [
            for (final item in _items)
              _ShopCard(
                item: item,
                priceLabel: _priceLabel(item),
                priceIcon: _priceIcon(item),
                canAfford: _canAfford(gs, item),
                onBuy: () => _buy(context, gs, item),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.item,
    required this.priceLabel,
    required this.priceIcon,
    required this.canAfford,
    required this.onBuy,
  });
  final _ShopItem item;
  final String priceLabel;
  final String priceIcon;
  final bool canAfford;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return EggPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Image.asset(item.icon)),
          Text(item.title,
              style: AppText.body(13, color: AppColors.textDark),
              maxLines: 1),
          const SizedBox(height: 4),
          _rewardsRow(),
          const SizedBox(height: 6),
          EggButton(
            onTap: onBuy,
            enabled: canAfford,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(priceIcon, width: 20, height: 20),
                const SizedBox(width: 3),
                Text(priceLabel, style: AppText.title(15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardsRow() {
    final parts = <Widget>[];
    void add(String icon, int v) {
      if (v > 0) {
        parts.add(Image.asset(icon, width: 16, height: 16));
        parts.add(Text(' $v ',
            style: AppText.body(11, color: AppColors.textDark)));
      }
    }

    add(Assets.egg, item.eggs);
    add(Assets.coin, item.coins);
    add(Assets.feather, item.feathers);
    return Wrap(alignment: WrapAlignment.center, children: parts);
  }
}
