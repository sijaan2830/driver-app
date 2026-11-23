import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/geo.dart';
import '../models.dart';
import '../theme.dart';

/// OpenStreetMap view with the van and job stops. No API key needed.
class RouteMap extends StatefulWidget {
  const RouteMap({super.key, this.me, this.heading = 0, this.stops = const [], this.focus, this.follow = false, this.line = false, this.interactive = true});
  final LatLng? me;
  final double heading;
  final List<Job> stops;
  final Job? focus; // highlighted stop
  final bool follow; // keep the camera on the van
  final bool line; // draw a line van → focus
  final bool interactive;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final _ctrl = MapController();
  bool _ready = false;

  List<LatLng> get _points => [
        if (widget.me != null) widget.me!,
        for (final s in widget.stops)
          if (s.hasGeo) LatLng(s.lat!, s.lng!),
      ];

  @override
  void didUpdateWidget(covariant RouteMap old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    if (widget.follow && widget.me != null && old.me != widget.me) {
      _ctrl.move(widget.me!, _ctrl.camera.zoom < 14 ? 15 : _ctrl.camera.zoom);
    } else if (!widget.follow && (old.focus?.id != widget.focus?.id || old.stops.length != widget.stops.length)) {
      _fit();
    }
  }

  void _fit() {
    final pts = _points;
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _ctrl.move(pts.first, 15);
      return;
    }
    _ctrl.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.fromLTRB(50, 70, 50, 70), maxZoom: 16));
  }

  @override
  Widget build(BuildContext context) {
    final pts = _points;
    final focus = widget.focus;
    return FlutterMap(
      mapController: _ctrl,
      options: MapOptions(
        initialCenter: pts.isEmpty ? Geo.london : pts.first,
        initialZoom: 13,
        initialCameraFit: pts.length > 1 ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.fromLTRB(50, 70, 50, 70), maxZoom: 16) : null,
        interactionOptions: InteractionOptions(flags: widget.interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none),
        onMapReady: () => _ready = true,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
          subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
          userAgentPackageName: 'com.drycleanplus.dc_driver',
          maxZoom: 20,
        ),
        if (widget.line && widget.me != null && focus != null && focus.hasGeo)
          PolylineLayer(polylines: [
            // High-contrast outer casing line
            Polyline(points: [widget.me!, LatLng(focus.lat!, focus.lng!)], strokeWidth: 9, color: const Color(0xFF1E3A8A)),
            // Bold royal blue navigation route line
            Polyline(points: [widget.me!, LatLng(focus.lat!, focus.lng!)], strokeWidth: 6, color: const Color(0xFF2563EB)),
          ]),
        MarkerLayer(markers: [
          for (final s in widget.stops)
            if (s.hasGeo)
              Marker(
                point: LatLng(s.lat!, s.lng!),
                width: (focus != null && focus.id == s.id) ? 140 : 46,
                height: (focus != null && focus.id == s.id) ? 75 : 54,
                alignment: Alignment.topCenter,
                child: _StopPin(job: s, highlighted: focus == null || focus.id == s.id, isDestination: focus?.id == s.id),
              ),
          if (widget.me != null) Marker(point: widget.me!, width: 52, height: 52, child: _Van(heading: widget.heading)),
        ]),
        const RichAttributionWidget(attributions: [TextSourceAttribution('Google Maps')]),
      ],
    );
  }
}

class _Van extends StatelessWidget {
  const _Van({required this.heading});
  final double heading;
  @override
  Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: DC.emerald.withValues(alpha: .18), shape: BoxShape.circle)),
        Transform.rotate(
          angle: heading * math.pi / 180,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: DC.forest, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: DC.shadow(.4)),
            child: const Icon(Icons.navigation_rounded, color: DC.gold, size: 19),
          ),
        ),
      ]);
}

class _StopPin extends StatelessWidget {
  const _StopPin({required this.job, required this.highlighted, this.isDestination = false});
  final Job job;
  final bool highlighted;
  final bool isDestination;

  @override
  Widget build(BuildContext context) {
    final done = job.isDone;
    final color = done ? DC.mut : (isDestination ? const Color(0xFF2563EB) : (job.isPickup ? DC.amber : DC.emerald));

    if (isDestination && !done) {
      final arrived = job.status == JobStatus.arrived;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: arrived ? const Color(0xFFB45309) : const Color(0xFF1E3A8A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(arrived ? Icons.front_hand_rounded : Icons.where_to_vote_rounded, color: Colors.yellowAccent, size: 14),
                const SizedBox(width: 4),
                Text(
                  arrived ? 'STOP HERE' : 'DESTINATION',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: arrived ? const Color(0xFFD97706) : const Color(0xFF2563EB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: DC.shadow(.3),
            ),
            alignment: Alignment.center,
            child: Text('${job.sequence}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          Container(width: 3, height: 8, color: arrived ? const Color(0xFFB45309) : const Color(0xFF1E3A8A)),
        ],
      );
    }

    return Opacity(
      opacity: highlighted ? 1 : .55,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 3), boxShadow: DC.shadow(.3)),
          alignment: Alignment.center,
          child: done
              ? Icon(job.status == JobStatus.failed ? Icons.close_rounded : Icons.check_rounded, color: color, size: 20)
              : Text('${job.sequence}', style: DC.h(15, color: color)),
        ),
        Container(width: 3, height: 10, color: color),
      ]),
    );
  }
}
