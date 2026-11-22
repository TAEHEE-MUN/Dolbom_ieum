import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'figma_assets.dart';

abstract final class AppColors {
  static const green = Color(0xff4ca771);
  static const pale = Color(0xffeaf9e7);
  static const mintBorder = Color(0xffc0e6ba);
  static const ink = Color(0xff202124);
  static const deep = Color(0xff013237);
  static const muted = Color(0xff6a6c70);
  static const line = Color(0xffdeded9);
}

Widget txt(
  String value, {
  double size = 16,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  TextAlign? align,
}) => Text(
  value,
  textAlign: align,
  style: TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.5,
  ),
);
Widget heading(String value) => txt(value, size: 28, weight: FontWeight.w800);
Widget gap([double height = 18]) => SizedBox(height: height);

class FigmaIcon extends StatelessWidget {
  const FigmaIcon(this.frame, this.name, {this.size = 22, super.key});
  final String frame, name;
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/figma/${figmaAssets[frame]![name]}',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

class AppButton extends StatelessWidget {
  const AppButton(
    this.label,
    this.onTap, {
    this.primary = true,
    this.icon,
    this.small = false,
    super.key,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary, small;
  final Widget? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: primary ? AppColors.green : Colors.white,
        foregroundColor: primary ? Colors.white : AppColors.ink,
        minimumSize: Size(0, small ? 58 : 62),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: primary
              ? BorderSide.none
              : const BorderSide(color: Color(0xffc8c9c6)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 9)],
          Flexible(
            child: txt(
              label,
              size: small ? 15 : 18,
              weight: FontWeight.w800,
              color: primary ? Colors.white : AppColors.ink,
              align: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.color = Colors.white,
    this.border = AppColors.line,
    this.padding = 20,
    this.radius = 18,
    this.shadow = false,
    super.key,
  });
  final Widget child;
  final Color color, border;
  final double padding, radius;
  final bool shadow;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: shadow
          ? [
              const BoxShadow(
                color: Color(0x0a202124),
                blurRadius: 18,
                offset: Offset(0, 5),
              ),
            ]
          : null,
    ),
    child: child,
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    final done = label == '종료';
    final warning = label == '답변 필요';
    final pending = label == '승인 대기';
    final neutral = label == '확인 중';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: neutral
            ? const Color(0xfff5f5f2)
            : done
            ? AppColors.green
            : warning
            ? const Color(0xffffe7e7)
            : pending
            ? const Color(0xfffff5c5)
            : AppColors.pale,
        border: Border.all(
          color: neutral
              ? AppColors.line
              : warning
              ? const Color(0xffff7070)
              : pending
              ? const Color(0xffedce55)
              : done
              ? AppColors.green
              : AppColors.mintBorder,
        ),
      ),
      child: txt(
        label,
        size: 14,
        weight: FontWeight.w800,
        color: neutral
            ? AppColors.muted
            : done
            ? Colors.white
            : warning
            ? const Color(0xff702525)
            : AppColors.deep,
      ),
    );
  }
}

class AppNotice extends StatelessWidget {
  const AppNotice({
    required this.child,
    this.icon,
    this.neutral = false,
    super.key,
  });
  final Widget child;
  final Widget? icon;
  final bool neutral;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: 16,
    radius: 14,
    color: neutral ? const Color(0xfff5f5f2) : AppColors.pale,
    border: neutral ? AppColors.line : AppColors.mintBorder,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(padding: const EdgeInsets.only(top: 3), child: icon!),
          const SizedBox(width: 14),
        ],
        Expanded(child: child),
      ],
    ),
  );
}

class AppField extends StatelessWidget {
  const AppField({
    required this.label,
    required this.controller,
    this.hint = '',
    this.lines = 1,
    this.obscure = false,
    this.keyboard,
    this.error,
    super.key,
  });
  final String label, hint;
  final TextEditingController controller;
  final int lines;
  final bool obscure;
  final TextInputType? keyboard;
  final String? error;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label.isNotEmpty) ...[txt(label, weight: FontWeight.w700), gap(9)],
      TextField(
        controller: controller,
        obscureText: obscure,
        maxLines: lines,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 16, height: 1.5),
        decoration: InputDecoration(
          hintText: hint,
          errorText: error,
          hintStyle: const TextStyle(color: Color(0xff909294)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 17,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xffc8c9c6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.deep, width: 2),
          ),
        ),
      ),
    ],
  );
}

class Brand extends StatelessWidget {
  const Brand({this.size = 20, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        const TextSpan(
          text: '돌봄',
          style: TextStyle(color: AppColors.green),
        ),
        const TextSpan(
          text: '이음',
          style: TextStyle(color: Colors.black),
        ),
      ],
    ),
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -.6,
    ),
  );
}

/// Original Figma SVG layers, at their design coordinates on a 132px canvas.
class Mascot extends StatelessWidget {
  const Mascot({this.active = false, super.key});
  final bool active;
  Widget layer(String name, double x, double y, double w, double h) =>
      Positioned(
        left: x,
        top: y,
        width: w,
        height: h,
        child: SvgPicture.asset(
          'assets/figma/$name',
          excludeFromSemantics: true,
        ),
      );
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 132,
    height: 132,
    child: Stack(
      children: [
        if (active) ...[
          layer('89b0f.svg', 39.12, 98.75, 23.12, 21.97),
          layer('87cf0.svg', 70.75, 98.75, 21.73, 21.23),
        ] else
          layer('e64d5.svg', 39.12, 98.75, 53.37, 21.97),
        layer(active ? '1d1ba.svg' : '815a0.svg', 92.75, 52.96, 27.9, 33.28),
        layer(active ? '69459.svg' : '4db50.svg', 46.75, 10.64, 36.51, 24.61),
        layer('d417d.svg', 21.63, 28.29, 80.68, 84.96),
        layer('5e139.svg', 37, 65, 56, 19),
      ],
    ),
  );
}
