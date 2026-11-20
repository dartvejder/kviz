import 'package:flutter/material.dart';

import 'tema/vidzeti.dart';

export 'tema/kontroler.dart';
export 'tema/model.dart';
export 'tema/ukrasi.dart';
export 'tema/vidzeti.dart';

/// Veliko dugme na početnom ekranu.
class VelikoDugme extends StatelessWidget {
  const VelikoDugme({
    super.key,
    required this.ikona,
    required this.tekst,
    this.onTap,
    this.glavno = false,
    this.zatamnjeno = false,
    this.desno,
  });
  final IconData ikona;
  final String tekst;
  final VoidCallback? onTap;
  final bool glavno;

  /// Vidno slabije (npr. završena soba), ali i dalje može da se pritisne.
  final bool zatamnjeno;

  /// Dodatno dugme desno (npr. kantica za brisanje).
  final Widget? desno;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Opacity(
      opacity: onTap == null ? .55 : (zatamnjeno ? .7 : 1),
      child: TemaDugme(
        glavno: glavno,
        onTap: onTap,
        child: Row(
          children: [
            Icon(ikona),
            const SizedBox(width: 14),
            if (desno == null) Flexible(child: Text(tekst)) else Expanded(child: Text(tekst)),
            ?desno,
          ],
        ),
      ),
    ),
  );
}
