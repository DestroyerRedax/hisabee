import '../../core/result/result.dart';
import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<Result<void>> saveProfile(Profile profile);
  Future<Result<String?>> getActiveProfileId();
  Future<Result<void>> setActiveProfileId(String profileId);
  Future<Result<List<Profile>>> getActiveProfiles();
  Future<Result<void>> softDeleteProfile({
    required String profileId,
    required int deletedAtMicroseconds,
    String? targetReassignProfileId,
  });
}
