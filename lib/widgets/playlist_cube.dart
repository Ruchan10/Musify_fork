/*
 *     Copyright (C) 2025 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify_fork/API/musify.dart';
import 'package:musify_fork/widgets/playlist_artwork.dart';

class PlaylistCube extends StatelessWidget {
  PlaylistCube(
    this.playlist, {
    super.key,
    this.playlistData,
    this.cubeIcon = FluentIcons.music_note_1_24_regular,
    this.size = 220,
    this.onClickOpen = true,
    this.borderRadius = 13,
  }) : playlistLikeStatus = ValueNotifier<bool>(
         isPlaylistAlreadyLiked(playlist['ytid']),
       );

  final Map? playlistData;
  final Map playlist;
  final IconData cubeIcon;
  final double size;
  final bool onClickOpen;

  final double borderRadius;

  static const double paddingValue = 4;
  static const double typeLabelOffset = 10;

  final ValueNotifier<bool> playlistLikeStatus;

  static const likeStatusToIconMapper = {
    true: FluentIcons.heart_24_filled,
    false: FluentIcons.heart_24_regular,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PlaylistArtwork(
            playlistArtwork: playlist['image'],
            size: size,
            cubeIcon: cubeIcon,
          ),
          if (borderRadius == 13 && playlist['image'] != null)
            Positioned(
              top: typeLabelOffset,
              right: typeLabelOffset,
              child: _buildLabel(context),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(paddingValue),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        playlist['isAlbum'] != null && playlist['isAlbum'] == true
            ? 'Album'
            : 'Playlist',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
