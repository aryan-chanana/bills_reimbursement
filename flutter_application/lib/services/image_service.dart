import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class ImageService {
  static final ImageService instance = ImageService._init();
  ImageService._init();

  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndSaveImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return await _saveImageToAppDirectory(File(pickedFile.path));
      }
    } catch (e) {
      print('Error picking image: $e');
    }
    return null;
  }

  Future<String?> captureAndSaveImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return await _saveImageToAppDirectory(File(pickedFile.path));
      }
    } catch (e) {
      print('Error capturing image: $e');
    }
    return null;
  }

  Future<String> _saveImageToAppDirectory(File imageFile) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String billsDir = path.join(appDocDir.path, 'bill_images');

    await Directory(billsDir).create(recursive: true);

    final String fileName = 'bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String filePath = path.join(billsDir, fileName);

    final File savedImage = await imageFile.copy(filePath);
    return savedImage.path;
  }

  Future<File?> getImageFile(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      print('Error getting image file: $e');
    }
    return null;
  }

  Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      print('Error deleting image: $e');
    }
    return false;
  }

  Future<String> getImagesDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String billsDir = path.join(appDocDir.path, 'bill_images');
    await Directory(billsDir).create(recursive: true);
    return billsDir;
  }
}