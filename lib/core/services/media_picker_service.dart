import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

/// Media Picker Service
/// Handles image, video, and PDF selection with editing capabilities
class MediaPickerService {
  final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return null;
      return File(image.path);
    } catch (_) {
      return null;
    }
  }

  /// Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return null;
      return File(image.path);
    } catch (_) {
      return null;
    }
  }

  /// Pick video from gallery
  Future<File?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video == null) return null;

      final file = File(video.path);
      final fileSize = await file.length();
      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('Video size must be less than 50MB');
      }

      return file;
    } catch (_) {
      rethrow;
    }
  }

  /// Pick video from camera
  Future<File?> pickVideoFromCamera() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (video == null) return null;

      final file = File(video.path);
      final fileSize = await file.length();
      if (fileSize > 50 * 1024 * 1024) {
        throw Exception('Video size must be less than 50MB');
      }

      return file;
    } catch (_) {
      rethrow;
    }
  }

  /// Pick PDF file
  Future<File?> pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final path = result.files.single.path;
      if (path == null) return null;

      final file = File(path);
      final fileSize = await file.length();
      if (fileSize > 20 * 1024 * 1024) {
        throw Exception('PDF size must be less than 20MB');
      }

      return file;
    } catch (_) {
      rethrow;
    }
  }

  /// Crop image
  Future<File?> cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: const Color(0xFF1A1A2E),
            toolbarWidgetColor: const Color(0xFFFFFFFF),
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );

      if (croppedFile == null) return null;
      return File(croppedFile.path);
    } catch (_) {
      return null;
    }
  }
}
