import '../../../../shared/models/post.dart';

class PostFormValidationResult {
  final bool isValid;
  final PostFormIssue? issue;

  const PostFormValidationResult._({
    required this.isValid,
    required this.issue,
  });

  factory PostFormValidationResult.valid() =>
      const PostFormValidationResult._(isValid: true, issue: null);

  factory PostFormValidationResult.invalid(PostFormIssue issue) =>
      PostFormValidationResult._(isValid: false, issue: issue);
}

enum PostFormIssue {
  captionMissing,
  captionTooShort,
  categoryMissing,
  textContentMissing,
  mediaMissing,
}

class PostFormValidator {
  static PostFormValidationResult validate({
    required ContentType contentType,
    required String caption,
    required String category,
    required bool hasMedia,
    required String bodyContent,
  }) {
    final normalizedCaption = caption.trim();
    if (normalizedCaption.isEmpty) {
      return PostFormValidationResult.invalid(PostFormIssue.captionMissing);
    }
    if (normalizedCaption.length < 3) {
      return PostFormValidationResult.invalid(PostFormIssue.captionTooShort);
    }

    if (category.trim().isEmpty) {
      return PostFormValidationResult.invalid(PostFormIssue.categoryMissing);
    }

    if (contentType.isTextBased && bodyContent.trim().isEmpty) {
      return PostFormValidationResult.invalid(PostFormIssue.textContentMissing);
    }

    if (contentType.requiresMedia && !hasMedia) {
      return PostFormValidationResult.invalid(PostFormIssue.mediaMissing);
    }

    return PostFormValidationResult.valid();
  }
}
