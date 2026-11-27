// DocuCraft — Template Registry
// Memuat metadata template dari template Presenton dan menyediakannya untuk editing AI

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'template_layout.dart';

class TemplateRegistry {
  static TemplateRegistry? _instance;
  static TemplateRegistry get instance => _instance ??= TemplateRegistry._();

  TemplateRegistry._();

  /// All registered template groups
  final List<TemplateGroup> groups = [];

  /// Layout data per layoutId (hasil konversi React .tsx → JSON)
  final Map<String, TemplateLayoutData> layoutData = {};

  /// Register layout data (dipanggil saat load JSON)
  void addLayoutData(TemplateLayoutData layout) {
    layoutData[layout.layoutId] = layout;
  }

  /// Load all template layouts from assets JSON (per folder)
  static Future<void> loadSwiftLayouts() async {
    await _loadFolder('swift', 'Swift', const [
      'IntroSlideLayout', 'MetricsNumbers', 'SimpleBulletPointsLayout',
      'IconBulletListDescription', 'BulletsWithIconsTitleDescription',
      'ImageListDescription', 'TableOfContents', 'TableorChart', 'Timeline',
    ]);
  }

  static Future<void> loadStandardLayouts() async {
    await _loadFolder('standard', 'Standard', const [
      'IntroSlideLayout', 'ChartLeftTextRightLayout', 'ContactLayout',
      'HeadingBulletImageDescriptionLayout', 'IconBulletDescriptionLayout',
      'IconImageDescriptionLayout', 'ImageListWithDescriptionLayout',
      'MetricsDescriptionLayout', 'NumberedBulletSingleImageLayout',
      'TableOfContentsLayout', 'VisualMetricsSlideLayout',
    ]);
  }

  static Future<void> loadModernLayouts() async {
    await _loadFolder('modern', 'Modern', const [
      'IntroSlideLayout', 'BulletWithIconsSlideLayout', 'BulletsWithIconsDescriptionGrid',
      'ChartOrTableWithDescription', 'ChartOrTableWithMetricsDescription',
      'ImageAndDescriptionLayout', 'ImageListWithDescriptionSlideLayout',
      'ImagesWithDescriptionLayout', 'MetricsWithDescription',
      'ModernChartPrimitives', 'TableOfContentsLayout',
    ]);
  }

  static Future<void> loadGeneralLayouts() async {
    await _loadFolder('general', 'General', const [
      'BasicInfoSlideLayout', 'BulletIconsOnlySlideLayout', 'BulletWithIconsSlideLayout',
      'ChartWithBulletsSlideLayout', 'GeneralChartPrimitives', 'IntroSlideLayout',
      'MetricsSlideLayout', 'MetricsWithImageSlideLayout', 'NumberedBulletsSlideLayout',
      'QuoteSlideLayout', 'TableInfoSlideLayout', 'TableOfContentsSlideLayout',
      'TeamSlideLayout',
    ]);
  }

  static Future<void> loadEducationLayouts() async {
    await _loadFolder('education', 'Education', const [
      'EducationCoverSlide', 'EducationLearningOutcomesSlide', 'EducationStatisticsGridSlide',
      'EducationTimelineSlide', 'EducationAboutSlide', 'EducationAssessmentRubricSlide',
      'EducationContentSplitSlide', 'EducationCurriculumStructureSlide',
      'EducationImageGallerySlide', 'EducationLessonPlanSlide', 'EducationQAContactSlide',
      'EducationReportChartSlide', 'EducationServicesSplitSlide',
      'EducationChartPrimitives', 'EducationTableOfContentsSlide',
    ]);
  }

  static Future<void> loadNeoSwiftLayouts() async {
    await _loadFolder('neo-swift', 'Neo Swift', const [
      'TitleCenteredChart', 'TitleDescriptionImageRight', 'TitleDescriptionFourChartsSixBullets',
      'TitleDescriptionBulletList', 'TitleDescriptionDataTable', 'TitleDescriptionMetricsGrid',
      'TitleDescriptionMetricsGridImage', 'TitleDescriptionSixChartsFourMetrics',
      'TitleDescriptionSixChartsGrid', 'TitleDualComparisonBlocks', 'TitleLabelDescriptionStatCards',
      'TitleSubtitleTeamMemberCards', 'TitleTaglineDescriptionNumberedSteps',
      'TitleThreeByThreeMetricsGrid', 'NeoChartPrimitives', 'TitleChartMetricsSidebar',
    ]);
  }

  static Future<void> loadCodeLayouts() async {
    await _loadFolder('code', 'Code', const [
      'CoverSlide', 'CodeExplanationSplitSlide', 'MetricsGridSlide', 'FullCodeBlockSlide',
      'TerminalCommandSlide', 'APIRequestResponseSlide', 'CardsGridSlide', 'WorkflowSlide',
      'CodeOutputSlide', 'CodeDiffComparisonSlide', 'DescriptionAndMetricsSlide',
      'DescriptionTextSlide', 'FileTreeStructureSlide', 'TableSlide',
      'TableOfContentSlide', 'TwoColumnBulletListSlide', 'CodeBlockPanel',
    ]);
  }

  static Future<void> loadNeoModernLayouts() async {
    await _loadFolder('neo-modern', 'Neo Modern', const [
      'TitleDescriptionBulletList', 'TitleDescriptionContactList', 'TitleDescriptionDualMetricsGrid',
      'TitleDescriptionImageRight', 'TitleDescriptionMetricsChart', 'TitleDescriptionMetricsImage',
      'TitleDescriptionMultiChartGrid', 'TitleDescriptionMultiChartGridWithBullets',
      'TitleDescriptionMultiChartGridWithMetrics', 'TitleDescriptionTable',
      'TitleDescriptionIconTimeline', 'TitleDualComparisonCards',
      'TitleDualComparisonCharts', 'TitleHorizontalAlternatingTimeline',
      'TitleKpiSnapshotGrid', 'TitleSubtitlesChart', 'TitleTwoColumnNumberedList',
      'NeoChartPrimitives',
    ]);
  }

  static Future<void> loadNeoStandardLayouts() async {
    await _loadFolder('neo-standard', 'Neo Standard', const [
      'TitleDescriptionBulletList', 'TitleDescriptionImageRight', 'TitleDescriptionMultiChartGrid',
      'TitleDescriptionContactCards', 'TitleDescriptionIconList', 'TitleDescriptionRadialCards',
      'TitleDescriptionTable', 'TitleDescriptionTimeline', 'TitleDualChartsComparison',
      'TitleDescriptionMultiChartGridWithBullets', 'TitleDescriptionMultiChartGridWithMetrics',
      'TitleDualComparisonCards', 'TitleKpiGrid', 'TitleMetricsChart',
      'TitleMetricsImage', 'TitlePointsDonutGrid', 'TitleBadgeChart', 'NeoChartPrimitives',
    ]);
  }

  static Future<void> loadProductOverviewLayouts() async {
    await _loadFolder('product-overview', 'Product Overview', const [
      'CoverSlide', 'IntroductionSlide', 'MissionVisionSlide', 'BusinessChallengesCardsSlide',
      'BusinessChallengesGridSlide', 'ComparisonChartSlide', 'ComparisonTableWithTextSlide',
      'FeatureHighlightsSlide', 'ImageGallerySlide', 'KpiCardsSlide', 'MeetTeamSlide',
      'OurServicesSlide', 'ProcessSlide', 'ProductRoadmapSlide', 'ReportSnapshotSlide',
      'TableOfContentSlide', 'TargetAudienceSlide', 'UseCasesSlide',
    ]);
  }

  static Future<void> loadReportLayouts() async {
    await _loadFolder('report', 'Report', const [
      'IntroCoverSlide', 'ExecutiveSummarySlide', 'KeyFindingsSlide', 'RecommendationsSlide',
      'MetricsSlide', 'RiskLimitationsSlide', 'ActionPlanSlide', 'AppendixNotesSlide',
      'ClosingContactSlide', 'DataAnalysisDashboardSlide', 'MethodologySourcesSlide',
      'MilestoneSlide', 'ReportSectionIndexSlide', 'BarChartWithBulletListWithTitleDescriptionIconSlide',
      'BulletListWithIconTitleDescriptionSlide', 'TitleChartWithMetricsCardsSlide',
      'TitleDescriptionChartSlide', 'TitleDescriptionImageSlide', 'TitleImageBulletCardsSlide',
      'TitleMetricsSlide', 'TitleWorkflowWithTitleDescriptionSlide',
      'HorizontalHeightSpanningImagesWithTitleSlide', 'flexibleReportChart',
    ]);
  }

  static Future<void> loadPitchDeckLayouts() async {
    await _loadFolder('pitch-deck', 'Pitch Deck', const [
      'CenteredCoverWithFooterMeta', 'ProblemEvidenceSlide', 'MarketSizeSlide',
      'BusinessModelSlide', 'TractionMetricsSlide', 'CompetitivePositioningSlide',
      'GoToMarketSlide', 'FinancialProjectionSlide', 'FundingAskSlide',
      'AdaptiveMediaCardGrid', 'AdaptiveValueCardGrid', 'CardsWithChartSplit',
      'ClosingContactSlide', 'DefensibilitySlide', 'FullWidthStatement',
      'HeadlineWithDetailColumns', 'HorizontalTimeline', 'MediaAndTextSplit',
      'TextAndChartSplit', 'NumberedMultiColumnOverview', 'OverlappingCircleCards',
      'PanelListWithMedia', 'PitchDeckChart', 'ProductWorkflowSlide', 'TeamCredentialsSlide',
    ]);
  }

  static Future<void> loadNeoGeneralLayouts() async {
    await _loadFolder('neo-general', 'Neo General', const [
      'BulletIconsOnlySlideLayout', 'BulletWithIconsSlideLayout',
      'ChallengeAndOutcomeWithOneStat', 'ChartWithBulletsSlideLayout',
      'GridBasedEightMetricsSnapshots', 'HeadlineDescriptionWithDoubleImage',
      'HeadlineDescriptionWithImage', 'HeadlineTextWithBulletsAndStats',
      'IndexedThreeColumnList', 'LayoutTextBlockWithMetricCards',
      'LeftAlignQuote', 'MetricsWithImageSlideLayout',
      'MultiChartGridSlideLayout', 'NeoChartPrimitives',
      'NumberedBulletsSlideLayout', 'QuoteSlideLayout',
      'TableOfContentWithoutPageNumber', 'TeamSlideLayout',
      'TextSplitWithEmphasisBlock', 'ThankYouContactInfoFooterImageSlide',
      'Timeline', 'TitleDescriptionMultiChartGridWithBullets',
      'TitleDescriptionMultiChartGridWithMetrics', 'TitleDescriptionWithTable',
      'TitleMetricValueMetricLabelFunnelStages', 'TitleMetricsWithChart',
      'TitleThreeColumnRiskConstraints', 'TitleTopDescriptionFourTeamMembersGrid',
      'TitleWithFullWidthChart', 'TitleWithGridBasedHeadingAndDescription',
    ]);
  }

  static Future<void> _loadFolder(String folder, String label, List<String> files) async {
    // Baca semua asset paralel (I/O), lalu parse & daftar berurutan —
    // urutan layouts per group tetap stabil, tapi startup jauh lebih cepat.
    final raws = await Future.wait(files.map((name) async {
      final path = 'assets/templates/$folder/$name.json';
      try {
        return await rootBundle.loadString(path);
      } catch (e) {
        // ignore broken JSON asset, tapi log supaya ketahuan
        debugPrint('⚠️ Gagal load template: $path → $e');
        return null;
      }
    }));

    for (var i = 0; i < files.length; i++) {
      final raw = raws[i];
      if (raw == null) continue;
      final name = files[i];
      try {
        final data = TemplateLayoutData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        instance.layoutData[data.layoutId] = data;

        // Pastikan group ada di registry
        if (!instance.groups.any((g) => g.name == folder)) {
          instance.groups.add(TemplateGroup(name: folder, label: label, layouts: []));
        }
        instance.groups.firstWhere((g) => g.name == folder).layouts.add(
          TemplateLayout(
            layoutId: data.layoutId,
            name: data.name,
            description: data.description,
            fields: [],
            sampleData: {},
            fileName: '$folder/$name.json',
          ),
        );
      } catch (e) {
        debugPrint('⚠️ Gagal parse template: $folder/$name → $e');
      }
    }
  }

  /// Get templates for a specific group
  List<TemplateLayout> templatesFor(String group) =>
    groups.where((g) => g.name == group).expand((g) => g.layouts).toList();

  /// Find template by layout ID
  TemplateLayout? findById(String id) {
    for (final g in groups) {
      for (final l in g.layouts) {
        if (l.layoutId == id) return l;
      }
    }
    return null;
  }
}

class TemplateGroup {
  final String name;
  final String label;
  final List<TemplateLayout> layouts;

  const TemplateGroup({required this.name, required this.label, required this.layouts});
}

class TemplateLayout {
  final String layoutId;
  final String name;
  final String description;

  /// Schema fields (extracted from Zod schema)
  final List<SchemaField> fields;

  /// Sample data (defaults from Zod)
  final Map<String, dynamic> sampleData;

  /// Template file name reference
  final String fileName;

  const TemplateLayout({
    required this.layoutId,
    required this.name,
    required this.description,
    required this.fields,
    required this.sampleData,
    required this.fileName,
  });
}

class SchemaField {
  final String name;
  final SchemaFieldType type;
  final int? minLength;
  final int? maxLength;
  final int? minItems;
  final int? maxItems;
  final String? description;
  final dynamic defaultValue;

  const SchemaField({
    required this.name,
    required this.type,
    this.minLength,
    this.maxLength,
    this.minItems,
    this.maxItems,
    this.description,
    this.defaultValue,
  });
}

enum SchemaFieldType { string, number, boolean, array, object }

