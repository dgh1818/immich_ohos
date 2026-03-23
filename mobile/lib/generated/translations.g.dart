// DO NOT EDIT. This is code generated via generate_keys.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/message_format.dart';

extension TranslationsExtension on BuildContext {
  Translations get t => Translations.of(this);
}

class StaticTranslations {
  StaticTranslations._();
  static final instance = Translations._(null);
}

abstract class _BaseTranslations {
  BuildContext? get _context;

  String _t(String key, [Map<String, Object>? args]) {
    if (key.isEmpty) return '';
    try {
      final translated = key.tr(context: _context);
      return args != null ? MessageFormat(translated, locale: Intl.defaultLocale ?? 'en').format(args) : translated;
    } catch (e) {
      return key;
    }
  }
}

class Translations extends _BaseTranslations {
  @override
  final BuildContext? _context;
  Translations._(this._context);

  static Translations of(BuildContext context) {
    context.locale;
    return Translations._(context);
  }

  String get about => _t('about');
  String get account => _t('account');
  String get account_settings => _t('account_settings');
  String get acknowledge => _t('acknowledge');
  String get action => _t('action');
  String get action_common_update => _t('action_common_update');
  String get action_description => _t('action_description');
  String get actions => _t('actions');
  String get active => _t('active');
  String active_count({required int count}) => _t('active_count', {'count': count});
  String get activity => _t('activity');
  String activity_changed({required bool enabled}) => _t('activity_changed', {'enabled': enabled});
  String get add => _t('add');
  String get add_a_description => _t('add_a_description');
  String get add_a_location => _t('add_a_location');
  String get add_a_name => _t('add_a_name');
  String get add_a_title => _t('add_a_title');
  String get add_action => _t('add_action');
  String get add_action_description => _t('add_action_description');
  String get add_assets => _t('add_assets');
  String get add_birthday => _t('add_birthday');
  String get add_endpoint => _t('add_endpoint');
  String get add_exclusion_pattern => _t('add_exclusion_pattern');
  String get add_filter => _t('add_filter');
  String get add_filter_description => _t('add_filter_description');
  String get add_location => _t('add_location');
  String get add_more_users => _t('add_more_users');
  String get add_partner => _t('add_partner');
  String get add_path => _t('add_path');
  String get add_photos => _t('add_photos');
  String get add_tag => _t('add_tag');
  String get add_to => _t('add_to');
  String get add_to_album => _t('add_to_album');
  String add_to_album_bottom_sheet_added({required Object album}) =>
      _t('add_to_album_bottom_sheet_added', {'album': album});
  String add_to_album_bottom_sheet_already_exists({required Object album}) =>
      _t('add_to_album_bottom_sheet_already_exists', {'album': album});
  String get add_to_album_bottom_sheet_some_local_assets => _t('add_to_album_bottom_sheet_some_local_assets');
  String add_to_album_toggle({required Object album}) => _t('add_to_album_toggle', {'album': album});
  String get add_to_albums => _t('add_to_albums');
  String add_to_albums_count({required int count}) => _t('add_to_albums_count', {'count': count});
  String get add_to_bottom_bar => _t('add_to_bottom_bar');
  String get add_to_shared_album => _t('add_to_shared_album');
  String get add_upload_to_stack => _t('add_upload_to_stack');
  String get add_url => _t('add_url');
  String get add_workflow_step => _t('add_workflow_step');
  String get added_to_archive => _t('added_to_archive');
  String get added_to_favorites => _t('added_to_favorites');
  String added_to_favorites_count({required int count}) => _t('added_to_favorites_count', {'count': count});
  late final admin = _AdminTranslations._(_context);
  String get admin_email => _t('admin_email');
  String get admin_password => _t('admin_password');
  String get administration => _t('administration');
  String get advanced => _t('advanced');
  String get advanced_settings_clear_image_cache => _t('advanced_settings_clear_image_cache');
  String get advanced_settings_clear_image_cache_error => _t('advanced_settings_clear_image_cache_error');
  String advanced_settings_clear_image_cache_success({required int size}) =>
      _t('advanced_settings_clear_image_cache_success', {'size': size});
  String get advanced_settings_enable_alternate_media_filter_subtitle =>
      _t('advanced_settings_enable_alternate_media_filter_subtitle');
  String get advanced_settings_enable_alternate_media_filter_title =>
      _t('advanced_settings_enable_alternate_media_filter_title');
  String advanced_settings_log_level_title({required Object level}) =>
      _t('advanced_settings_log_level_title', {'level': level});
  String get advanced_settings_prefer_remote_subtitle => _t('advanced_settings_prefer_remote_subtitle');
  String get advanced_settings_prefer_remote_title => _t('advanced_settings_prefer_remote_title');
  String get advanced_settings_proxy_headers_subtitle => _t('advanced_settings_proxy_headers_subtitle');
  String get advanced_settings_proxy_headers_title => _t('advanced_settings_proxy_headers_title');
  String get advanced_settings_readonly_mode_subtitle => _t('advanced_settings_readonly_mode_subtitle');
  String get advanced_settings_readonly_mode_title => _t('advanced_settings_readonly_mode_title');
  String get advanced_settings_self_signed_ssl_subtitle => _t('advanced_settings_self_signed_ssl_subtitle');
  String get advanced_settings_self_signed_ssl_title => _t('advanced_settings_self_signed_ssl_title');
  String get advanced_settings_sync_remote_deletions_subtitle => _t('advanced_settings_sync_remote_deletions_subtitle');
  String get advanced_settings_sync_remote_deletions_title => _t('advanced_settings_sync_remote_deletions_title');
  String get advanced_settings_tile_subtitle => _t('advanced_settings_tile_subtitle');
  String get advanced_settings_troubleshooting_subtitle => _t('advanced_settings_troubleshooting_subtitle');
  String get advanced_settings_troubleshooting_title => _t('advanced_settings_troubleshooting_title');
  String age_months({required int months}) => _t('age_months', {'months': months});
  String age_year_months({required int months}) => _t('age_year_months', {'months': months});
  String age_years({required int years}) => _t('age_years', {'years': years});
  String get album => _t('album');
  String get album_added => _t('album_added');
  String get album_added_notification_setting_description => _t('album_added_notification_setting_description');
  String get album_cover_updated => _t('album_cover_updated');
  String album_delete_confirmation({required Object album}) => _t('album_delete_confirmation', {'album': album});
  String get album_delete_confirmation_description => _t('album_delete_confirmation_description');
  String get album_deleted => _t('album_deleted');
  String get album_info_card_backup_album_excluded => _t('album_info_card_backup_album_excluded');
  String get album_info_card_backup_album_included => _t('album_info_card_backup_album_included');
  String get album_info_updated => _t('album_info_updated');
  String get album_leave => _t('album_leave');
  String album_leave_confirmation({required Object album}) => _t('album_leave_confirmation', {'album': album});
  String get album_name => _t('album_name');
  String get album_options => _t('album_options');
  String get album_remove_user => _t('album_remove_user');
  String album_remove_user_confirmation({required Object user}) => _t('album_remove_user_confirmation', {'user': user});
  String get album_search_not_found => _t('album_search_not_found');
  String get album_selected => _t('album_selected');
  String get album_share_no_users => _t('album_share_no_users');
  String get album_summary => _t('album_summary');
  String get album_updated => _t('album_updated');
  String get album_updated_setting_description => _t('album_updated_setting_description');
  String get album_upload_assets => _t('album_upload_assets');
  String album_user_left({required Object album}) => _t('album_user_left', {'album': album});
  String album_user_removed({required Object user}) => _t('album_user_removed', {'user': user});
  String get album_viewer_appbar_delete_confirm => _t('album_viewer_appbar_delete_confirm');
  String get album_viewer_appbar_share_err_delete => _t('album_viewer_appbar_share_err_delete');
  String get album_viewer_appbar_share_err_leave => _t('album_viewer_appbar_share_err_leave');
  String get album_viewer_appbar_share_err_remove => _t('album_viewer_appbar_share_err_remove');
  String get album_viewer_appbar_share_err_title => _t('album_viewer_appbar_share_err_title');
  String get album_viewer_appbar_share_leave => _t('album_viewer_appbar_share_leave');
  String get album_viewer_appbar_share_to => _t('album_viewer_appbar_share_to');
  String get album_viewer_page_share_add_users => _t('album_viewer_page_share_add_users');
  String get album_with_link_access => _t('album_with_link_access');
  String get albums => _t('albums');
  String albums_count({required int count}) => _t('albums_count', {'count': count});
  String get albums_default_sort_order => _t('albums_default_sort_order');
  String get albums_default_sort_order_description => _t('albums_default_sort_order_description');
  String get albums_feature_description => _t('albums_feature_description');
  String albums_on_device_count({required int count}) => _t('albums_on_device_count', {'count': count});
  String albums_selected({required int count}) => _t('albums_selected', {'count': count});
  String get all => _t('all');
  String get all_albums => _t('all_albums');
  String get all_people => _t('all_people');
  String get all_photos => _t('all_photos');
  String get all_videos => _t('all_videos');
  String get allow_dark_mode => _t('allow_dark_mode');
  String get allow_edits => _t('allow_edits');
  String get allow_public_user_to_download => _t('allow_public_user_to_download');
  String get allow_public_user_to_upload => _t('allow_public_user_to_upload');
  String get allowed => _t('allowed');
  String get alt_text_qr_code => _t('alt_text_qr_code');
  String get always_keep => _t('always_keep');
  String get always_keep_photos_hint => _t('always_keep_photos_hint');
  String get always_keep_videos_hint => _t('always_keep_videos_hint');
  String get anti_clockwise => _t('anti_clockwise');
  String get api_key => _t('api_key');
  String get api_key_description => _t('api_key_description');
  String get api_key_empty => _t('api_key_empty');
  String get api_keys => _t('api_keys');
  String get app_architecture_variant => _t('app_architecture_variant');
  String get app_bar_signout_dialog_content => _t('app_bar_signout_dialog_content');
  String get app_bar_signout_dialog_ok => _t('app_bar_signout_dialog_ok');
  String get app_bar_signout_dialog_title => _t('app_bar_signout_dialog_title');
  String get app_download_links => _t('app_download_links');
  String get app_settings => _t('app_settings');
  String get app_stores => _t('app_stores');
  String get app_update_available => _t('app_update_available');
  String get appears_in => _t('appears_in');
  String apply_count({required int count}) => _t('apply_count', {'count': count});
  String get archive => _t('archive');
  String archive_action_prompt({required int count}) => _t('archive_action_prompt', {'count': count});
  String get archive_or_unarchive_photo => _t('archive_or_unarchive_photo');
  String get archive_page_no_archived_assets => _t('archive_page_no_archived_assets');
  String archive_page_title({required int count}) => _t('archive_page_title', {'count': count});
  String get archive_size => _t('archive_size');
  String get archive_size_description => _t('archive_size_description');
  String get archived => _t('archived');
  String archived_count({required int count}) => _t('archived_count', {'count': count});
  String get are_these_the_same_person => _t('are_these_the_same_person');
  String get are_you_sure_to_do_this => _t('are_you_sure_to_do_this');
  String get array_field_not_fully_supported => _t('array_field_not_fully_supported');
  String get asset_action_delete_err_read_only => _t('asset_action_delete_err_read_only');
  String get asset_action_share_err_offline => _t('asset_action_share_err_offline');
  String get asset_added_to_album => _t('asset_added_to_album');
  String get asset_adding_to_album => _t('asset_adding_to_album');
  String get asset_created => _t('asset_created');
  String get asset_description_updated => _t('asset_description_updated');
  String asset_filename_is_offline({required Object filename}) =>
      _t('asset_filename_is_offline', {'filename': filename});
  String get asset_has_unassigned_faces => _t('asset_has_unassigned_faces');
  String get asset_hashing => _t('asset_hashing');
  String get asset_list_group_by_sub_title => _t('asset_list_group_by_sub_title');
  String get asset_list_layout_settings_dynamic_layout_title => _t('asset_list_layout_settings_dynamic_layout_title');
  String get asset_list_layout_settings_group_automatically => _t('asset_list_layout_settings_group_automatically');
  String get asset_list_layout_settings_group_by => _t('asset_list_layout_settings_group_by');
  String get asset_list_layout_settings_group_by_month_day => _t('asset_list_layout_settings_group_by_month_day');
  String get asset_list_layout_sub_title => _t('asset_list_layout_sub_title');
  String get asset_list_settings_subtitle => _t('asset_list_settings_subtitle');
  String get asset_list_settings_title => _t('asset_list_settings_title');
  String get asset_not_found_on_device_android => _t('asset_not_found_on_device_android');
  String get asset_not_found_on_device_ios => _t('asset_not_found_on_device_ios');
  String get asset_not_found_on_icloud => _t('asset_not_found_on_icloud');
  String get asset_offline => _t('asset_offline');
  String get asset_offline_description => _t('asset_offline_description');
  String get asset_restored_successfully => _t('asset_restored_successfully');
  String get asset_skipped => _t('asset_skipped');
  String get asset_skipped_in_trash => _t('asset_skipped_in_trash');
  String get asset_trashed => _t('asset_trashed');
  String get asset_troubleshoot => _t('asset_troubleshoot');
  String get asset_uploaded => _t('asset_uploaded');
  String get asset_uploading => _t('asset_uploading');
  String get asset_viewer_settings_subtitle => _t('asset_viewer_settings_subtitle');
  String get asset_viewer_settings_title => _t('asset_viewer_settings_title');
  String get assets => _t('assets');
  String assets_added_count({required int count}) => _t('assets_added_count', {'count': count});
  String assets_added_to_album_count({required int count}) => _t('assets_added_to_album_count', {'count': count});
  String assets_added_to_albums_count({required int assetTotal, required int albumTotal}) =>
      _t('assets_added_to_albums_count', {'assetTotal': assetTotal, 'albumTotal': albumTotal});
  String assets_cannot_be_added_to_album_count({required int count}) =>
      _t('assets_cannot_be_added_to_album_count', {'count': count});
  String assets_cannot_be_added_to_albums({required int count}) =>
      _t('assets_cannot_be_added_to_albums', {'count': count});
  String assets_count({required int count}) => _t('assets_count', {'count': count});
  String assets_deleted_permanently({required int count}) => _t('assets_deleted_permanently', {'count': count});
  String assets_deleted_permanently_from_server({required int count}) =>
      _t('assets_deleted_permanently_from_server', {'count': count});
  String assets_downloaded_failed({required int count}) => _t('assets_downloaded_failed', {'count': count});
  String assets_downloaded_successfully({required int count}) => _t('assets_downloaded_successfully', {'count': count});
  String assets_moved_to_trash_count({required int count}) => _t('assets_moved_to_trash_count', {'count': count});
  String assets_permanently_deleted_count({required int count}) =>
      _t('assets_permanently_deleted_count', {'count': count});
  String assets_removed_count({required int count}) => _t('assets_removed_count', {'count': count});
  String assets_removed_permanently_from_device({required int count}) =>
      _t('assets_removed_permanently_from_device', {'count': count});
  String get assets_restore_confirmation => _t('assets_restore_confirmation');
  String assets_restored_count({required int count}) => _t('assets_restored_count', {'count': count});
  String assets_restored_successfully({required int count}) => _t('assets_restored_successfully', {'count': count});
  String assets_trashed({required int count}) => _t('assets_trashed', {'count': count});
  String assets_trashed_count({required int count}) => _t('assets_trashed_count', {'count': count});
  String assets_trashed_from_server({required int count}) => _t('assets_trashed_from_server', {'count': count});
  String assets_were_part_of_album_count({required int count}) =>
      _t('assets_were_part_of_album_count', {'count': count});
  String assets_were_part_of_albums_count({required int count}) =>
      _t('assets_were_part_of_albums_count', {'count': count});
  String get authorized_devices => _t('authorized_devices');
  String get automatic_endpoint_switching_subtitle => _t('automatic_endpoint_switching_subtitle');
  String get automatic_endpoint_switching_title => _t('automatic_endpoint_switching_title');
  String get autoplay_slideshow => _t('autoplay_slideshow');
  String get back => _t('back');
  String get back_close_deselect => _t('back_close_deselect');
  String get background_backup_running_error => _t('background_backup_running_error');
  String get background_location_permission => _t('background_location_permission');
  String get background_location_permission_content => _t('background_location_permission_content');
  String get background_options => _t('background_options');
  String get backup => _t('backup');
  String backup_album_selection_page_albums_device({required int count}) =>
      _t('backup_album_selection_page_albums_device', {'count': count});
  String get backup_album_selection_page_albums_tap => _t('backup_album_selection_page_albums_tap');
  String get backup_album_selection_page_assets_scatter => _t('backup_album_selection_page_assets_scatter');
  String get backup_album_selection_page_select_albums => _t('backup_album_selection_page_select_albums');
  String get backup_album_selection_page_selection_info => _t('backup_album_selection_page_selection_info');
  String get backup_album_selection_page_total_assets => _t('backup_album_selection_page_total_assets');
  String get backup_albums_sync => _t('backup_albums_sync');
  String get backup_all => _t('backup_all');
  String get backup_background_service_backup_failed_message => _t('backup_background_service_backup_failed_message');
  String get backup_background_service_complete_notification => _t('backup_background_service_complete_notification');
  String get backup_background_service_connection_failed_message =>
      _t('backup_background_service_connection_failed_message');
  String backup_background_service_current_upload_notification({required Object filename}) =>
      _t('backup_background_service_current_upload_notification', {'filename': filename});
  String get backup_background_service_default_notification => _t('backup_background_service_default_notification');
  String get backup_background_service_error_title => _t('backup_background_service_error_title');
  String get backup_background_service_in_progress_notification =>
      _t('backup_background_service_in_progress_notification');
  String backup_background_service_upload_failure_notification({required Object filename}) =>
      _t('backup_background_service_upload_failure_notification', {'filename': filename});
  String get backup_controller_page_albums => _t('backup_controller_page_albums');
  String get backup_controller_page_background_app_refresh_disabled_content =>
      _t('backup_controller_page_background_app_refresh_disabled_content');
  String get backup_controller_page_background_app_refresh_disabled_title =>
      _t('backup_controller_page_background_app_refresh_disabled_title');
  String get backup_controller_page_background_app_refresh_enable_button_text =>
      _t('backup_controller_page_background_app_refresh_enable_button_text');
  String get backup_controller_page_background_battery_info_link =>
      _t('backup_controller_page_background_battery_info_link');
  String get backup_controller_page_background_battery_info_message =>
      _t('backup_controller_page_background_battery_info_message');
  String get backup_controller_page_background_battery_info_ok =>
      _t('backup_controller_page_background_battery_info_ok');
  String get backup_controller_page_background_battery_info_title =>
      _t('backup_controller_page_background_battery_info_title');
  String get backup_controller_page_background_charging => _t('backup_controller_page_background_charging');
  String get backup_controller_page_background_configure_error =>
      _t('backup_controller_page_background_configure_error');
  String backup_controller_page_background_delay({required Object duration}) =>
      _t('backup_controller_page_background_delay', {'duration': duration});
  String get backup_controller_page_background_description => _t('backup_controller_page_background_description');
  String get backup_controller_page_background_is_off => _t('backup_controller_page_background_is_off');
  String get backup_controller_page_background_is_on => _t('backup_controller_page_background_is_on');
  String get backup_controller_page_background_turn_off => _t('backup_controller_page_background_turn_off');
  String get backup_controller_page_background_turn_on => _t('backup_controller_page_background_turn_on');
  String get backup_controller_page_background_wifi => _t('backup_controller_page_background_wifi');
  String get backup_controller_page_backup => _t('backup_controller_page_backup');
  String get backup_controller_page_backup_selected => _t('backup_controller_page_backup_selected');
  String get backup_controller_page_backup_sub => _t('backup_controller_page_backup_sub');
  String backup_controller_page_created({required Object date}) => _t('backup_controller_page_created', {'date': date});
  String get backup_controller_page_desc_backup => _t('backup_controller_page_desc_backup');
  String get backup_controller_page_excluded => _t('backup_controller_page_excluded');
  String backup_controller_page_failed({required int count}) => _t('backup_controller_page_failed', {'count': count});
  String backup_controller_page_filename({required Object filename, required int size}) =>
      _t('backup_controller_page_filename', {'filename': filename, 'size': size});
  String backup_controller_page_id({required int id}) => _t('backup_controller_page_id', {'id': id});
  String get backup_controller_page_info => _t('backup_controller_page_info');
  String get backup_controller_page_none_selected => _t('backup_controller_page_none_selected');
  String get backup_controller_page_remainder => _t('backup_controller_page_remainder');
  String get backup_controller_page_remainder_sub => _t('backup_controller_page_remainder_sub');
  String get backup_controller_page_server_storage => _t('backup_controller_page_server_storage');
  String get backup_controller_page_start_backup => _t('backup_controller_page_start_backup');
  String get backup_controller_page_status_off => _t('backup_controller_page_status_off');
  String get backup_controller_page_status_on => _t('backup_controller_page_status_on');
  String backup_controller_page_storage_format({required Object used, required int total}) =>
      _t('backup_controller_page_storage_format', {'used': used, 'total': total});
  String get backup_controller_page_to_backup => _t('backup_controller_page_to_backup');
  String get backup_controller_page_total_sub => _t('backup_controller_page_total_sub');
  String get backup_controller_page_turn_off => _t('backup_controller_page_turn_off');
  String get backup_controller_page_turn_on => _t('backup_controller_page_turn_on');
  String get backup_controller_page_uploading_file_info => _t('backup_controller_page_uploading_file_info');
  String get backup_err_only_album => _t('backup_err_only_album');
  String get backup_error_sync_failed => _t('backup_error_sync_failed');
  String get backup_info_card_assets => _t('backup_info_card_assets');
  String get backup_manual_cancelled => _t('backup_manual_cancelled');
  String get backup_manual_in_progress => _t('backup_manual_in_progress');
  String get backup_manual_success => _t('backup_manual_success');
  String get backup_manual_title => _t('backup_manual_title');
  String get backup_options => _t('backup_options');
  String get backup_options_page_title => _t('backup_options_page_title');
  String get backup_setting_subtitle => _t('backup_setting_subtitle');
  String get backup_settings_subtitle => _t('backup_settings_subtitle');
  String get backup_upload_details_page_more_details => _t('backup_upload_details_page_more_details');
  String get backward => _t('backward');
  String get biometric_auth_enabled => _t('biometric_auth_enabled');
  String get biometric_locked_out => _t('biometric_locked_out');
  String get biometric_no_options => _t('biometric_no_options');
  String get biometric_not_available => _t('biometric_not_available');
  String get birthdate_saved => _t('birthdate_saved');
  String get birthdate_set_description => _t('birthdate_set_description');
  String get blurred_background => _t('blurred_background');
  String get bugs_and_feature_requests => _t('bugs_and_feature_requests');
  String get build => _t('build');
  String get build_image => _t('build_image');
  String bulk_delete_duplicates_confirmation({required int count}) =>
      _t('bulk_delete_duplicates_confirmation', {'count': count});
  String bulk_keep_duplicates_confirmation({required int count}) =>
      _t('bulk_keep_duplicates_confirmation', {'count': count});
  String bulk_trash_duplicates_confirmation({required int count}) =>
      _t('bulk_trash_duplicates_confirmation', {'count': count});
  String get buy => _t('buy');
  String get cache_settings_clear_cache_button => _t('cache_settings_clear_cache_button');
  String get cache_settings_clear_cache_button_title => _t('cache_settings_clear_cache_button_title');
  String get cache_settings_duplicated_assets_clear_button => _t('cache_settings_duplicated_assets_clear_button');
  String get cache_settings_duplicated_assets_subtitle => _t('cache_settings_duplicated_assets_subtitle');
  String cache_settings_duplicated_assets_title({required int count}) =>
      _t('cache_settings_duplicated_assets_title', {'count': count});
  String get cache_settings_statistics_album => _t('cache_settings_statistics_album');
  String get cache_settings_statistics_full => _t('cache_settings_statistics_full');
  String get cache_settings_statistics_shared => _t('cache_settings_statistics_shared');
  String get cache_settings_statistics_thumbnail => _t('cache_settings_statistics_thumbnail');
  String get cache_settings_statistics_title => _t('cache_settings_statistics_title');
  String get cache_settings_subtitle => _t('cache_settings_subtitle');
  String get cache_settings_tile_subtitle => _t('cache_settings_tile_subtitle');
  String get cache_settings_tile_title => _t('cache_settings_tile_title');
  String get cache_settings_title => _t('cache_settings_title');
  String get camera => _t('camera');
  String get camera_brand => _t('camera_brand');
  String get camera_model => _t('camera_model');
  String get cancel => _t('cancel');
  String get cancel_search => _t('cancel_search');
  String get canceled => _t('canceled');
  String get canceling => _t('canceling');
  String get cannot_merge_people => _t('cannot_merge_people');
  String get cannot_undo_this_action => _t('cannot_undo_this_action');
  String get cannot_update_the_description => _t('cannot_update_the_description');
  String get cast => _t('cast');
  String get cast_description => _t('cast_description');
  String get change_date => _t('change_date');
  String get change_description => _t('change_description');
  String get change_display_order => _t('change_display_order');
  String get change_expiration_time => _t('change_expiration_time');
  String get change_location => _t('change_location');
  String get change_name => _t('change_name');
  String get change_name_successfully => _t('change_name_successfully');
  String get change_password => _t('change_password');
  String get change_password_description => _t('change_password_description');
  String get change_password_form_confirm_password => _t('change_password_form_confirm_password');
  String change_password_form_description({required Object name}) =>
      _t('change_password_form_description', {'name': name});
  String get change_password_form_log_out => _t('change_password_form_log_out');
  String get change_password_form_log_out_description => _t('change_password_form_log_out_description');
  String get change_password_form_new_password => _t('change_password_form_new_password');
  String get change_password_form_password_mismatch => _t('change_password_form_password_mismatch');
  String get change_password_form_reenter_new_password => _t('change_password_form_reenter_new_password');
  String get change_pin_code => _t('change_pin_code');
  String get change_trigger => _t('change_trigger');
  String get change_trigger_prompt => _t('change_trigger_prompt');
  String get change_your_password => _t('change_your_password');
  String get changed_visibility_successfully => _t('changed_visibility_successfully');
  String get charging => _t('charging');
  String get charging_requirement_mobile_backup => _t('charging_requirement_mobile_backup');
  String get check_corrupt_asset_backup => _t('check_corrupt_asset_backup');
  String get check_corrupt_asset_backup_button => _t('check_corrupt_asset_backup_button');
  String get check_corrupt_asset_backup_description => _t('check_corrupt_asset_backup_description');
  String get check_logs => _t('check_logs');
  String get checksum => _t('checksum');
  String get choose_matching_people_to_merge => _t('choose_matching_people_to_merge');
  String get city => _t('city');
  String cleanup_confirm_description({required int count, required Object date}) =>
      _t('cleanup_confirm_description', {'count': count, 'date': date});
  String get cleanup_confirm_prompt_title => _t('cleanup_confirm_prompt_title');
  String cleanup_deleted_assets({required int count}) => _t('cleanup_deleted_assets', {'count': count});
  String get cleanup_deleting => _t('cleanup_deleting');
  String cleanup_found_assets({required int count}) => _t('cleanup_found_assets', {'count': count});
  String cleanup_found_assets_with_size({required int count, required int size}) =>
      _t('cleanup_found_assets_with_size', {'count': count, 'size': size});
  String get cleanup_icloud_shared_albums_excluded => _t('cleanup_icloud_shared_albums_excluded');
  String get cleanup_no_assets_found => _t('cleanup_no_assets_found');
  String cleanup_preview_title({required int count}) => _t('cleanup_preview_title', {'count': count});
  String get cleanup_step3_description => _t('cleanup_step3_description');
  String cleanup_step4_summary({required int count, required Object date}) =>
      _t('cleanup_step4_summary', {'count': count, 'date': date});
  String get cleanup_trash_hint => _t('cleanup_trash_hint');
  String get clear => _t('clear');
  String get clear_all => _t('clear_all');
  String get clear_all_recent_searches => _t('clear_all_recent_searches');
  String get clear_file_cache => _t('clear_file_cache');
  String get clear_message => _t('clear_message');
  String get clear_value => _t('clear_value');
  String get client_cert_dialog_msg_confirm => _t('client_cert_dialog_msg_confirm');
  String get client_cert_enter_password => _t('client_cert_enter_password');
  String get client_cert_import => _t('client_cert_import');
  String get client_cert_import_success_msg => _t('client_cert_import_success_msg');
  String get client_cert_invalid_msg => _t('client_cert_invalid_msg');
  String get client_cert_password_message => _t('client_cert_password_message');
  String get client_cert_password_title => _t('client_cert_password_title');
  String get client_cert_remove_msg => _t('client_cert_remove_msg');
  String get client_cert_subtitle => _t('client_cert_subtitle');
  String get client_cert_title => _t('client_cert_title');
  String get clockwise => _t('clockwise');
  String get close => _t('close');
  String get collapse => _t('collapse');
  String get collapse_all => _t('collapse_all');
  String get color => _t('color');
  String get color_theme => _t('color_theme');
  String get command => _t('command');
  String get command_palette_prompt => _t('command_palette_prompt');
  String get command_palette_to_close => _t('command_palette_to_close');
  String get command_palette_to_navigate => _t('command_palette_to_navigate');
  String get command_palette_to_select => _t('command_palette_to_select');
  String get command_palette_to_show_all => _t('command_palette_to_show_all');
  String get comment_deleted => _t('comment_deleted');
  String get comment_options => _t('comment_options');
  String get comments_and_likes => _t('comments_and_likes');
  String get comments_are_disabled => _t('comments_are_disabled');
  String get common_create_new_album => _t('common_create_new_album');
  String get completed => _t('completed');
  String get confirm => _t('confirm');
  String get confirm_admin_password => _t('confirm_admin_password');
  String confirm_delete_face({required Object name}) => _t('confirm_delete_face', {'name': name});
  String get confirm_delete_shared_link => _t('confirm_delete_shared_link');
  String get confirm_keep_this_delete_others => _t('confirm_keep_this_delete_others');
  String get confirm_new_pin_code => _t('confirm_new_pin_code');
  String get confirm_password => _t('confirm_password');
  String confirm_tag_face({required Object name}) => _t('confirm_tag_face', {'name': name});
  String get confirm_tag_face_unnamed => _t('confirm_tag_face_unnamed');
  String get connected_device => _t('connected_device');
  String get connected_to => _t('connected_to');
  String get contain => _t('contain');
  String get context => _t('context');
  String get continue$ => _t('continue');
  String get control_bottom_app_bar_create_new_album => _t('control_bottom_app_bar_create_new_album');
  String get control_bottom_app_bar_delete_from_immich => _t('control_bottom_app_bar_delete_from_immich');
  String get control_bottom_app_bar_delete_from_local => _t('control_bottom_app_bar_delete_from_local');
  String get control_bottom_app_bar_edit_location => _t('control_bottom_app_bar_edit_location');
  String get control_bottom_app_bar_edit_time => _t('control_bottom_app_bar_edit_time');
  String get control_bottom_app_bar_share_link => _t('control_bottom_app_bar_share_link');
  String get control_bottom_app_bar_share_to => _t('control_bottom_app_bar_share_to');
  String get control_bottom_app_bar_trash_from_immich => _t('control_bottom_app_bar_trash_from_immich');
  String get copied_image_to_clipboard => _t('copied_image_to_clipboard');
  String get copied_to_clipboard => _t('copied_to_clipboard');
  String get copy_error => _t('copy_error');
  String get copy_file_path => _t('copy_file_path');
  String get copy_image => _t('copy_image');
  String get copy_link => _t('copy_link');
  String get copy_link_to_clipboard => _t('copy_link_to_clipboard');
  String get copy_password => _t('copy_password');
  String get copy_to_clipboard => _t('copy_to_clipboard');
  String get country => _t('country');
  String get cover => _t('cover');
  String get covers => _t('covers');
  String get create => _t('create');
  String get create_album => _t('create_album');
  String get create_album_page_untitled => _t('create_album_page_untitled');
  String get create_api_key => _t('create_api_key');
  String get create_first_workflow => _t('create_first_workflow');
  String get create_library => _t('create_library');
  String get create_link => _t('create_link');
  String get create_link_to_share => _t('create_link_to_share');
  String get create_link_to_share_description => _t('create_link_to_share_description');
  String get create_new => _t('create_new');
  String get create_new_person => _t('create_new_person');
  String get create_new_person_hint => _t('create_new_person_hint');
  String get create_new_user => _t('create_new_user');
  String get create_shared_album_page_share_add_assets => _t('create_shared_album_page_share_add_assets');
  String get create_shared_album_page_share_select_photos => _t('create_shared_album_page_share_select_photos');
  String get create_shared_link => _t('create_shared_link');
  String get create_tag => _t('create_tag');
  String get create_tag_description => _t('create_tag_description');
  String get create_user => _t('create_user');
  String get create_workflow => _t('create_workflow');
  String get created => _t('created');
  String get created_at => _t('created_at');
  String get creating_linked_albums => _t('creating_linked_albums');
  String get crop => _t('crop');
  String get crop_aspect_ratio_fixed => _t('crop_aspect_ratio_fixed');
  String get crop_aspect_ratio_free => _t('crop_aspect_ratio_free');
  String get crop_aspect_ratio_original => _t('crop_aspect_ratio_original');
  String get curated_object_page_title => _t('curated_object_page_title');
  String get current_device => _t('current_device');
  String get current_pin_code => _t('current_pin_code');
  String get current_server_address => _t('current_server_address');
  String get custom_date => _t('custom_date');
  String get custom_locale => _t('custom_locale');
  String get custom_locale_description => _t('custom_locale_description');
  String get custom_url => _t('custom_url');
  String get cutoff_date_description => _t('cutoff_date_description');
  String cutoff_day({required int count}) => _t('cutoff_day', {'count': count});
  String cutoff_year({required int count}) => _t('cutoff_year', {'count': count});
  String get daily_title_text_date => _t('daily_title_text_date');
  String get daily_title_text_date_year => _t('daily_title_text_date_year');
  String get dark => _t('dark');
  String get dark_theme => _t('dark_theme');
  String get date => _t('date');
  String get date_after => _t('date_after');
  String get date_and_time => _t('date_and_time');
  String get date_before => _t('date_before');
  String get date_format => _t('date_format');
  String get date_of_birth_saved => _t('date_of_birth_saved');
  String get date_range => _t('date_range');
  String get day => _t('day');
  String get days => _t('days');
  String get deduplicate_all => _t('deduplicate_all');
  String get deduplication_criteria_1 => _t('deduplication_criteria_1');
  String get deduplication_criteria_2 => _t('deduplication_criteria_2');
  String get deduplication_info => _t('deduplication_info');
  String get deduplication_info_description => _t('deduplication_info_description');
  String get delete => _t('delete');
  String get delete_action_confirmation_message => _t('delete_action_confirmation_message');
  String delete_action_prompt({required int count}) => _t('delete_action_prompt', {'count': count});
  String get delete_album => _t('delete_album');
  String get delete_api_key_prompt => _t('delete_api_key_prompt');
  String get delete_dialog_alert => _t('delete_dialog_alert');
  String get delete_dialog_alert_local => _t('delete_dialog_alert_local');
  String get delete_dialog_alert_local_non_backed_up => _t('delete_dialog_alert_local_non_backed_up');
  String get delete_dialog_alert_remote => _t('delete_dialog_alert_remote');
  String get delete_dialog_ok_force => _t('delete_dialog_ok_force');
  String get delete_dialog_title => _t('delete_dialog_title');
  String get delete_duplicates_confirmation => _t('delete_duplicates_confirmation');
  String get delete_face => _t('delete_face');
  String get delete_key => _t('delete_key');
  String get delete_library => _t('delete_library');
  String get delete_link => _t('delete_link');
  String delete_local_action_prompt({required int count}) => _t('delete_local_action_prompt', {'count': count});
  String get delete_local_dialog_ok_backed_up_only => _t('delete_local_dialog_ok_backed_up_only');
  String get delete_local_dialog_ok_force => _t('delete_local_dialog_ok_force');
  String get delete_others => _t('delete_others');
  String get delete_permanently => _t('delete_permanently');
  String delete_permanently_action_prompt({required int count}) =>
      _t('delete_permanently_action_prompt', {'count': count});
  String get delete_shared_link => _t('delete_shared_link');
  String get delete_shared_link_dialog_title => _t('delete_shared_link_dialog_title');
  String get delete_tag => _t('delete_tag');
  String delete_tag_confirmation_prompt({required Object tagName}) =>
      _t('delete_tag_confirmation_prompt', {'tagName': tagName});
  String get delete_user => _t('delete_user');
  String get deleted_shared_link => _t('deleted_shared_link');
  String get deletes_missing_assets => _t('deletes_missing_assets');
  String get description => _t('description');
  String get description_input_hint_text => _t('description_input_hint_text');
  String get description_input_submit_error => _t('description_input_submit_error');
  String get deselect_all => _t('deselect_all');
  String get details => _t('details');
  String get direction => _t('direction');
  String get disable => _t('disable');
  String get disabled => _t('disabled');
  String get disallow_edits => _t('disallow_edits');
  String get discord => _t('discord');
  String get discover => _t('discover');
  String get discovered_devices => _t('discovered_devices');
  String get dismiss_all_errors => _t('dismiss_all_errors');
  String get dismiss_error => _t('dismiss_error');
  String get display_options => _t('display_options');
  String get display_order => _t('display_order');
  String get display_original_photos => _t('display_original_photos');
  String get display_original_photos_setting_description => _t('display_original_photos_setting_description');
  String get do_not_show_again => _t('do_not_show_again');
  String get documentation => _t('documentation');
  String get done => _t('done');
  String get download => _t('download');
  String download_action_prompt({required int count}) => _t('download_action_prompt', {'count': count});
  String get download_canceled => _t('download_canceled');
  String get download_complete => _t('download_complete');
  String get download_enqueue => _t('download_enqueue');
  String get download_error => _t('download_error');
  String get download_failed => _t('download_failed');
  String get download_finished => _t('download_finished');
  String get download_include_embedded_motion_videos => _t('download_include_embedded_motion_videos');
  String get download_include_embedded_motion_videos_description =>
      _t('download_include_embedded_motion_videos_description');
  String get download_notfound => _t('download_notfound');
  String get download_original => _t('download_original');
  String get download_paused => _t('download_paused');
  String get download_settings => _t('download_settings');
  String get download_settings_description => _t('download_settings_description');
  String get download_started => _t('download_started');
  String get download_sucess => _t('download_sucess');
  String get download_sucess_android => _t('download_sucess_android');
  String get download_waiting_to_retry => _t('download_waiting_to_retry');
  String get downloading => _t('downloading');
  String downloading_asset_filename({required Object filename}) =>
      _t('downloading_asset_filename', {'filename': filename});
  String get downloading_from_icloud => _t('downloading_from_icloud');
  String get downloading_media => _t('downloading_media');
  String get drop_files_to_upload => _t('drop_files_to_upload');
  String get duplicates => _t('duplicates');
  String get duplicates_description => _t('duplicates_description');
  String get duration => _t('duration');
  String get edit => _t('edit');
  String get edit_album => _t('edit_album');
  String get edit_avatar => _t('edit_avatar');
  String get edit_birthday => _t('edit_birthday');
  String get edit_date => _t('edit_date');
  String get edit_date_and_time => _t('edit_date_and_time');
  String edit_date_and_time_action_prompt({required int count}) =>
      _t('edit_date_and_time_action_prompt', {'count': count});
  String get edit_date_and_time_by_offset => _t('edit_date_and_time_by_offset');
  String edit_date_and_time_by_offset_interval({required Object from, required Object to}) =>
      _t('edit_date_and_time_by_offset_interval', {'from': from, 'to': to});
  String get edit_description => _t('edit_description');
  String get edit_description_prompt => _t('edit_description_prompt');
  String get edit_exclusion_pattern => _t('edit_exclusion_pattern');
  String get edit_faces => _t('edit_faces');
  String get edit_key => _t('edit_key');
  String get edit_link => _t('edit_link');
  String get edit_location => _t('edit_location');
  String edit_location_action_prompt({required int count}) => _t('edit_location_action_prompt', {'count': count});
  String get edit_location_dialog_title => _t('edit_location_dialog_title');
  String get edit_name => _t('edit_name');
  String get edit_people => _t('edit_people');
  String get edit_tag => _t('edit_tag');
  String get edit_title => _t('edit_title');
  String get edit_user => _t('edit_user');
  String get edit_workflow => _t('edit_workflow');
  String get editor => _t('editor');
  String get editor_close_without_save_prompt => _t('editor_close_without_save_prompt');
  String get editor_close_without_save_title => _t('editor_close_without_save_title');
  String get editor_confirm_reset_all_changes => _t('editor_confirm_reset_all_changes');
  String get editor_discard_edits_confirm => _t('editor_discard_edits_confirm');
  String get editor_discard_edits_prompt => _t('editor_discard_edits_prompt');
  String get editor_discard_edits_title => _t('editor_discard_edits_title');
  String get editor_edits_applied_error => _t('editor_edits_applied_error');
  String get editor_edits_applied_success => _t('editor_edits_applied_success');
  String get editor_flip_horizontal => _t('editor_flip_horizontal');
  String get editor_flip_vertical => _t('editor_flip_vertical');
  String editor_handle_corner({required String corner}) => _t('editor_handle_corner', {'corner': corner});
  String editor_handle_edge({required String edge}) => _t('editor_handle_edge', {'edge': edge});
  String get editor_orientation => _t('editor_orientation');
  String get editor_reset_all_changes => _t('editor_reset_all_changes');
  String get editor_rotate_left => _t('editor_rotate_left');
  String get editor_rotate_right => _t('editor_rotate_right');
  String get email => _t('email');
  String get email_notifications => _t('email_notifications');
  String get empty_folder => _t('empty_folder');
  String get empty_trash => _t('empty_trash');
  String get empty_trash_confirmation => _t('empty_trash_confirmation');
  String get enable => _t('enable');
  String get enable_backup => _t('enable_backup');
  String get enable_biometric_auth_description => _t('enable_biometric_auth_description');
  String get enabled => _t('enabled');
  String get end_date => _t('end_date');
  String get enqueued => _t('enqueued');
  String get enter_wifi_name => _t('enter_wifi_name');
  String get enter_your_pin_code => _t('enter_your_pin_code');
  String get enter_your_pin_code_subtitle => _t('enter_your_pin_code_subtitle');
  String get error => _t('error');
  String get error_change_sort_album => _t('error_change_sort_album');
  String get error_delete_face => _t('error_delete_face');
  String get error_getting_places => _t('error_getting_places');
  String get error_loading_albums => _t('error_loading_albums');
  String get error_loading_image => _t('error_loading_image');
  String error_loading_partners({required Object error}) => _t('error_loading_partners', {'error': error});
  String get error_retrieving_asset_information => _t('error_retrieving_asset_information');
  String error_saving_image({required Object error}) => _t('error_saving_image', {'error': error});
  String get error_tag_face_bounding_box => _t('error_tag_face_bounding_box');
  String get error_title => _t('error_title');
  String get error_while_navigating => _t('error_while_navigating');
  late final errors = _ErrorsTranslations._(_context);
  String get errors_text => _t('errors_text');
  String get exclusion_pattern => _t('exclusion_pattern');
  String get exif => _t('exif');
  String get exif_bottom_sheet_description => _t('exif_bottom_sheet_description');
  String get exif_bottom_sheet_description_error => _t('exif_bottom_sheet_description_error');
  String get exif_bottom_sheet_details => _t('exif_bottom_sheet_details');
  String get exif_bottom_sheet_location => _t('exif_bottom_sheet_location');
  String get exif_bottom_sheet_no_description => _t('exif_bottom_sheet_no_description');
  String get exif_bottom_sheet_people => _t('exif_bottom_sheet_people');
  String get exif_bottom_sheet_person_add_person => _t('exif_bottom_sheet_person_add_person');
  String get exit_slideshow => _t('exit_slideshow');
  String get expand => _t('expand');
  String get expand_all => _t('expand_all');
  String get experimental_settings_new_asset_list_subtitle => _t('experimental_settings_new_asset_list_subtitle');
  String get experimental_settings_new_asset_list_title => _t('experimental_settings_new_asset_list_title');
  String get experimental_settings_subtitle => _t('experimental_settings_subtitle');
  String get experimental_settings_title => _t('experimental_settings_title');
  String get expire_after => _t('expire_after');
  String get expired => _t('expired');
  String expires_date({required Object date}) => _t('expires_date', {'date': date});
  String get explore => _t('explore');
  String get explorer => _t('explorer');
  String get export$ => _t('export');
  String get export_as_json => _t('export_as_json');
  String get export_database => _t('export_database');
  String get export_database_description => _t('export_database_description');
  String get extension$ => _t('extension');
  String get external$ => _t('external');
  String get external_libraries => _t('external_libraries');
  String get external_network => _t('external_network');
  String get external_network_sheet_info => _t('external_network_sheet_info');
  String get face_unassigned => _t('face_unassigned');
  String get failed => _t('failed');
  String failed_count({required int count}) => _t('failed_count', {'count': count});
  String get failed_to_authenticate => _t('failed_to_authenticate');
  String get failed_to_load_assets => _t('failed_to_load_assets');
  String get failed_to_load_folder => _t('failed_to_load_folder');
  String get favorite => _t('favorite');
  String favorite_action_prompt({required int count}) => _t('favorite_action_prompt', {'count': count});
  String get favorite_or_unfavorite_photo => _t('favorite_or_unfavorite_photo');
  String get favorites => _t('favorites');
  String get favorites_page_no_favorites => _t('favorites_page_no_favorites');
  String get feature_photo_updated => _t('feature_photo_updated');
  String get features => _t('features');
  String get features_in_development => _t('features_in_development');
  String get features_setting_description => _t('features_setting_description');
  String get file_name_or_extension => _t('file_name_or_extension');
  String get file_name_text => _t('file_name_text');
  String file_name_with_value({required Object file_name}) => _t('file_name_with_value', {'file_name': file_name});
  String get file_size => _t('file_size');
  String get filename => _t('filename');
  String get filetype => _t('filetype');
  String get filter => _t('filter');
  String get filter_description => _t('filter_description');
  String get filter_people => _t('filter_people');
  String get filter_places => _t('filter_places');
  String get filter_tags => _t('filter_tags');
  String get filters => _t('filters');
  String get find_them_fast => _t('find_them_fast');
  String get first => _t('first');
  String get fix_incorrect_match => _t('fix_incorrect_match');
  String get folder => _t('folder');
  String get folder_not_found => _t('folder_not_found');
  String get folders => _t('folders');
  String get folders_feature_description => _t('folders_feature_description');
  String get forgot_pin_code_question => _t('forgot_pin_code_question');
  String get forward => _t('forward');
  String get free_up_space => _t('free_up_space');
  String get free_up_space_description => _t('free_up_space_description');
  String get free_up_space_settings_subtitle => _t('free_up_space_settings_subtitle');
  String full_path({required Object path}) => _t('full_path', {'path': path});
  String get gcast_enabled => _t('gcast_enabled');
  String get gcast_enabled_description => _t('gcast_enabled_description');
  String get general => _t('general');
  String get geolocation_instruction_location => _t('geolocation_instruction_location');
  String get get_help => _t('get_help');
  String get get_people_error => _t('get_people_error');
  String get get_wifiname_error => _t('get_wifiname_error');
  String get getting_started => _t('getting_started');
  String get go_back => _t('go_back');
  String get go_to_folder => _t('go_to_folder');
  String get go_to_search => _t('go_to_search');
  String get gps => _t('gps');
  String get gps_missing => _t('gps_missing');
  String get grant_permission => _t('grant_permission');
  String get group_albums_by => _t('group_albums_by');
  String get group_country => _t('group_country');
  String get group_no => _t('group_no');
  String get group_owner => _t('group_owner');
  String get group_places_by => _t('group_places_by');
  String get group_year => _t('group_year');
  String get haptic_feedback_switch => _t('haptic_feedback_switch');
  String get haptic_feedback_title => _t('haptic_feedback_title');
  String get has_quota => _t('has_quota');
  String get hash_asset => _t('hash_asset');
  String get hashed_assets => _t('hashed_assets');
  String get hashing => _t('hashing');
  String get header_settings_add_header_tip => _t('header_settings_add_header_tip');
  String get header_settings_field_validator_msg => _t('header_settings_field_validator_msg');
  String get header_settings_header_name_input => _t('header_settings_header_name_input');
  String get header_settings_header_value_input => _t('header_settings_header_value_input');
  String get headers_settings_tile_title => _t('headers_settings_tile_title');
  String get height => _t('height');
  String hi_user({required Object name, required Object email}) => _t('hi_user', {'name': name, 'email': email});
  String get hide_all_people => _t('hide_all_people');
  String get hide_gallery => _t('hide_gallery');
  String hide_named_person({required Object name}) => _t('hide_named_person', {'name': name});
  String get hide_password => _t('hide_password');
  String get hide_person => _t('hide_person');
  String get hide_schema => _t('hide_schema');
  String get hide_text_recognition => _t('hide_text_recognition');
  String get hide_unnamed_people => _t('hide_unnamed_people');
  String home_page_add_to_album_conflicts({required Object added, required Object album, required Object failed}) =>
      _t('home_page_add_to_album_conflicts', {'added': added, 'album': album, 'failed': failed});
  String get home_page_add_to_album_err_local => _t('home_page_add_to_album_err_local');
  String home_page_add_to_album_success({required Object added, required Object album}) =>
      _t('home_page_add_to_album_success', {'added': added, 'album': album});
  String get home_page_album_err_partner => _t('home_page_album_err_partner');
  String get home_page_archive_err_local => _t('home_page_archive_err_local');
  String get home_page_archive_err_partner => _t('home_page_archive_err_partner');
  String get home_page_building_timeline => _t('home_page_building_timeline');
  String get home_page_delete_err_partner => _t('home_page_delete_err_partner');
  String get home_page_delete_remote_err_local => _t('home_page_delete_remote_err_local');
  String get home_page_favorite_err_local => _t('home_page_favorite_err_local');
  String get home_page_favorite_err_partner => _t('home_page_favorite_err_partner');
  String get home_page_first_time_notice => _t('home_page_first_time_notice');
  String get home_page_locked_error_local => _t('home_page_locked_error_local');
  String get home_page_locked_error_partner => _t('home_page_locked_error_partner');
  String get home_page_share_err_local => _t('home_page_share_err_local');
  String get home_page_upload_err_limit => _t('home_page_upload_err_limit');
  String get host => _t('host');
  String get hour => _t('hour');
  String get hours => _t('hours');
  String get id => _t('id');
  String get idle => _t('idle');
  String get ignore_icloud_photos => _t('ignore_icloud_photos');
  String get ignore_icloud_photos_description => _t('ignore_icloud_photos_description');
  String get image => _t('image');
  String image_alt_text_date({required bool isVideo, required Object date}) =>
      _t('image_alt_text_date', {'isVideo': isVideo, 'date': date});
  String image_alt_text_date_1_person({required bool isVideo, required Object person1, required Object date}) =>
      _t('image_alt_text_date_1_person', {'isVideo': isVideo, 'person1': person1, 'date': date});
  String image_alt_text_date_2_people({
    required bool isVideo,
    required Object person1,
    required Object person2,
    required Object date,
  }) => _t('image_alt_text_date_2_people', {'isVideo': isVideo, 'person1': person1, 'person2': person2, 'date': date});
  String image_alt_text_date_3_people({
    required bool isVideo,
    required Object person1,
    required Object person2,
    required Object person3,
    required Object date,
  }) => _t('image_alt_text_date_3_people', {
    'isVideo': isVideo,
    'person1': person1,
    'person2': person2,
    'person3': person3,
    'date': date,
  });
  String image_alt_text_date_4_or_more_people({
    required bool isVideo,
    required int additionalCount,
    required Object person1,
    required Object person2,
    required Object date,
  }) => _t('image_alt_text_date_4_or_more_people', {
    'isVideo': isVideo,
    'additionalCount': additionalCount,
    'person1': person1,
    'person2': person2,
    'date': date,
  });
  String image_alt_text_date_place({
    required bool isVideo,
    required Object city,
    required Object country,
    required Object date,
  }) => _t('image_alt_text_date_place', {'isVideo': isVideo, 'city': city, 'country': country, 'date': date});
  String image_alt_text_date_place_1_person({
    required bool isVideo,
    required Object city,
    required Object country,
    required Object person1,
    required Object date,
  }) => _t('image_alt_text_date_place_1_person', {
    'isVideo': isVideo,
    'city': city,
    'country': country,
    'person1': person1,
    'date': date,
  });
  String image_alt_text_date_place_2_people({
    required bool isVideo,
    required Object city,
    required Object country,
    required Object person1,
    required Object person2,
    required Object date,
  }) => _t('image_alt_text_date_place_2_people', {
    'isVideo': isVideo,
    'city': city,
    'country': country,
    'person1': person1,
    'person2': person2,
    'date': date,
  });
  String image_alt_text_date_place_3_people({
    required bool isVideo,
    required Object city,
    required Object country,
    required Object person1,
    required Object person2,
    required Object person3,
    required Object date,
  }) => _t('image_alt_text_date_place_3_people', {
    'isVideo': isVideo,
    'city': city,
    'country': country,
    'person1': person1,
    'person2': person2,
    'person3': person3,
    'date': date,
  });
  String image_alt_text_date_place_4_or_more_people({
    required bool isVideo,
    required int additionalCount,
    required Object city,
    required Object country,
    required Object person1,
    required Object person2,
    required Object date,
  }) => _t('image_alt_text_date_place_4_or_more_people', {
    'isVideo': isVideo,
    'additionalCount': additionalCount,
    'city': city,
    'country': country,
    'person1': person1,
    'person2': person2,
    'date': date,
  });
  String get image_saved_successfully => _t('image_saved_successfully');
  String get image_viewer_page_state_provider_download_started =>
      _t('image_viewer_page_state_provider_download_started');
  String get image_viewer_page_state_provider_download_success =>
      _t('image_viewer_page_state_provider_download_success');
  String get image_viewer_page_state_provider_share_error => _t('image_viewer_page_state_provider_share_error');
  String get immich_logo => _t('immich_logo');
  String get immich_web_interface => _t('immich_web_interface');
  String get import_from_json => _t('import_from_json');
  String get import_path => _t('import_path');
  String in_albums({required int count}) => _t('in_albums', {'count': count});
  String get in_archive => _t('in_archive');
  String in_year({required int year}) => _t('in_year', {'year': year});
  String get in_year_selector => _t('in_year_selector');
  String get include_archived => _t('include_archived');
  String get include_shared_albums => _t('include_shared_albums');
  String get include_shared_partner_assets => _t('include_shared_partner_assets');
  String get individual_share => _t('individual_share');
  String get individual_shares => _t('individual_shares');
  String get info => _t('info');
  late final interval = _IntervalTranslations._(_context);
  String get invalid_date => _t('invalid_date');
  String get invalid_date_format => _t('invalid_date_format');
  String get invite_people => _t('invite_people');
  String get invite_to_album => _t('invite_to_album');
  String ios_debug_info_fetch_ran_at({required Object dateTime}) =>
      _t('ios_debug_info_fetch_ran_at', {'dateTime': dateTime});
  String ios_debug_info_last_sync_at({required Object dateTime}) =>
      _t('ios_debug_info_last_sync_at', {'dateTime': dateTime});
  String get ios_debug_info_no_processes_queued => _t('ios_debug_info_no_processes_queued');
  String get ios_debug_info_no_sync_yet => _t('ios_debug_info_no_sync_yet');
  String ios_debug_info_processes_queued({required int count}) =>
      _t('ios_debug_info_processes_queued', {'count': count});
  String ios_debug_info_processing_ran_at({required Object dateTime}) =>
      _t('ios_debug_info_processing_ran_at', {'dateTime': dateTime});
  String items_count({required int count}) => _t('items_count', {'count': count});
  String get jobs => _t('jobs');
  String get json_editor => _t('json_editor');
  String get json_error => _t('json_error');
  String get keep => _t('keep');
  String get keep_albums => _t('keep_albums');
  String keep_albums_count({required int count}) => _t('keep_albums_count', {'count': count});
  String get keep_all => _t('keep_all');
  String get keep_description => _t('keep_description');
  String get keep_favorites => _t('keep_favorites');
  String get keep_on_device => _t('keep_on_device');
  String get keep_on_device_hint => _t('keep_on_device_hint');
  String get keep_this_delete_others => _t('keep_this_delete_others');
  String keeping({required Object items}) => _t('keeping', {'items': items});
  String kept_this_deleted_others({required int count}) => _t('kept_this_deleted_others', {'count': count});
  String get keyboard_shortcuts => _t('keyboard_shortcuts');
  String get language => _t('language');
  String get language_no_results_subtitle => _t('language_no_results_subtitle');
  String get language_no_results_title => _t('language_no_results_title');
  String get language_search_hint => _t('language_search_hint');
  String get language_setting_description => _t('language_setting_description');
  String get large_files => _t('large_files');
  String get last => _t('last');
  String last_months({required int count}) => _t('last_months', {'count': count});
  String get last_seen => _t('last_seen');
  String get latest_version => _t('latest_version');
  String get latitude => _t('latitude');
  String get leave => _t('leave');
  String get leave_album => _t('leave_album');
  String get lens_model => _t('lens_model');
  String get let_others_respond => _t('let_others_respond');
  String get level => _t('level');
  String get library$ => _t('library');
  String get library_add_folder => _t('library_add_folder');
  String get library_edit_folder => _t('library_edit_folder');
  String get library_options => _t('library_options');
  String get library_page_device_albums => _t('library_page_device_albums');
  String get library_page_new_album => _t('library_page_new_album');
  String get library_page_sort_asset_count => _t('library_page_sort_asset_count');
  String get library_page_sort_created => _t('library_page_sort_created');
  String get library_page_sort_last_modified => _t('library_page_sort_last_modified');
  String get library_page_sort_title => _t('library_page_sort_title');
  String get licenses => _t('licenses');
  String get light => _t('light');
  String get like => _t('like');
  String get like_deleted => _t('like_deleted');
  String get link_motion_video => _t('link_motion_video');
  String get link_to_oauth => _t('link_to_oauth');
  String get linked_oauth_account => _t('linked_oauth_account');
  String get list => _t('list');
  String get loading => _t('loading');
  String get loading_search_results_failed => _t('loading_search_results_failed');
  String get local => _t('local');
  String get local_asset_cast_failed => _t('local_asset_cast_failed');
  String get local_assets => _t('local_assets');
  String get local_id => _t('local_id');
  String get local_media_summary => _t('local_media_summary');
  String get local_network => _t('local_network');
  String get local_network_sheet_info => _t('local_network_sheet_info');
  String get location => _t('location');
  String get location_permission => _t('location_permission');
  String get location_permission_content => _t('location_permission_content');
  String get location_picker_choose_on_map => _t('location_picker_choose_on_map');
  String get location_picker_latitude_error => _t('location_picker_latitude_error');
  String get location_picker_latitude_hint => _t('location_picker_latitude_hint');
  String get location_picker_longitude_error => _t('location_picker_longitude_error');
  String get location_picker_longitude_hint => _t('location_picker_longitude_hint');
  String get lock => _t('lock');
  String get locked_folder => _t('locked_folder');
  String get log_detail_title => _t('log_detail_title');
  String get log_out => _t('log_out');
  String get log_out_all_devices => _t('log_out_all_devices');
  String logged_in_as({required Object user}) => _t('logged_in_as', {'user': user});
  String get logged_out_all_devices => _t('logged_out_all_devices');
  String get logged_out_device => _t('logged_out_device');
  String get login => _t('login');
  String get login_disabled => _t('login_disabled');
  String get login_form_api_exception => _t('login_form_api_exception');
  String get login_form_back_button_text => _t('login_form_back_button_text');
  String get login_form_email_hint => _t('login_form_email_hint');
  String get login_form_endpoint_hint => _t('login_form_endpoint_hint');
  String get login_form_endpoint_url => _t('login_form_endpoint_url');
  String get login_form_err_http => _t('login_form_err_http');
  String get login_form_err_invalid_email => _t('login_form_err_invalid_email');
  String get login_form_err_invalid_url => _t('login_form_err_invalid_url');
  String get login_form_err_leading_whitespace => _t('login_form_err_leading_whitespace');
  String get login_form_err_trailing_whitespace => _t('login_form_err_trailing_whitespace');
  String get login_form_failed_get_oauth_server_config => _t('login_form_failed_get_oauth_server_config');
  String get login_form_failed_get_oauth_server_disable => _t('login_form_failed_get_oauth_server_disable');
  String get login_form_failed_login => _t('login_form_failed_login');
  String get login_form_handshake_exception => _t('login_form_handshake_exception');
  String get login_form_password_hint => _t('login_form_password_hint');
  String get login_form_save_login => _t('login_form_save_login');
  String get login_form_server_empty => _t('login_form_server_empty');
  String get login_form_server_error => _t('login_form_server_error');
  String get login_has_been_disabled => _t('login_has_been_disabled');
  String get login_password_changed_error => _t('login_password_changed_error');
  String get login_password_changed_success => _t('login_password_changed_success');
  String get logout_all_device_confirmation => _t('logout_all_device_confirmation');
  String get logout_this_device_confirmation => _t('logout_this_device_confirmation');
  String get logs => _t('logs');
  String get longitude => _t('longitude');
  String get look => _t('look');
  String get loop_videos => _t('loop_videos');
  String get loop_videos_description => _t('loop_videos_description');
  String get main_branch_warning => _t('main_branch_warning');
  String get main_menu => _t('main_menu');
  String get maintenance_action_restore => _t('maintenance_action_restore');
  String get maintenance_description => _t('maintenance_description');
  String get maintenance_end => _t('maintenance_end');
  String get maintenance_end_error => _t('maintenance_end_error');
  String maintenance_logged_in_as({required Object user}) => _t('maintenance_logged_in_as', {'user': user});
  String get maintenance_restore_from_backup => _t('maintenance_restore_from_backup');
  String get maintenance_restore_library => _t('maintenance_restore_library');
  String get maintenance_restore_library_confirm => _t('maintenance_restore_library_confirm');
  String get maintenance_restore_library_description => _t('maintenance_restore_library_description');
  String maintenance_restore_library_folder_has_files({required Object folder, required int count}) =>
      _t('maintenance_restore_library_folder_has_files', {'folder': folder, 'count': count});
  String maintenance_restore_library_folder_no_files({required Object folder}) =>
      _t('maintenance_restore_library_folder_no_files', {'folder': folder});
  String get maintenance_restore_library_folder_pass => _t('maintenance_restore_library_folder_pass');
  String get maintenance_restore_library_folder_read_fail => _t('maintenance_restore_library_folder_read_fail');
  String get maintenance_restore_library_folder_write_fail => _t('maintenance_restore_library_folder_write_fail');
  String get maintenance_restore_library_hint_missing_files => _t('maintenance_restore_library_hint_missing_files');
  String get maintenance_restore_library_hint_regenerate_later =>
      _t('maintenance_restore_library_hint_regenerate_later');
  String get maintenance_restore_library_hint_storage_template_missing_files =>
      _t('maintenance_restore_library_hint_storage_template_missing_files');
  String get maintenance_restore_library_loading => _t('maintenance_restore_library_loading');
  String get maintenance_task_backup => _t('maintenance_task_backup');
  String get maintenance_task_migrations => _t('maintenance_task_migrations');
  String get maintenance_task_restore => _t('maintenance_task_restore');
  String get maintenance_task_rollback => _t('maintenance_task_rollback');
  String get maintenance_title => _t('maintenance_title');
  String get make => _t('make');
  String get manage_geolocation => _t('manage_geolocation');
  String get manage_media_access_rationale => _t('manage_media_access_rationale');
  String get manage_media_access_settings => _t('manage_media_access_settings');
  String get manage_media_access_subtitle => _t('manage_media_access_subtitle');
  String get manage_media_access_title => _t('manage_media_access_title');
  String get manage_shared_links => _t('manage_shared_links');
  String get manage_sharing_with_partners => _t('manage_sharing_with_partners');
  String get manage_the_app_settings => _t('manage_the_app_settings');
  String get manage_your_account => _t('manage_your_account');
  String get manage_your_api_keys => _t('manage_your_api_keys');
  String get manage_your_devices => _t('manage_your_devices');
  String get manage_your_oauth_connection => _t('manage_your_oauth_connection');
  String get map => _t('map');
  String map_assets_in_bounds({required int count}) => _t('map_assets_in_bounds', {'count': count});
  String get map_cannot_get_user_location => _t('map_cannot_get_user_location');
  String get map_location_dialog_yes => _t('map_location_dialog_yes');
  String get map_location_picker_page_use_location => _t('map_location_picker_page_use_location');
  String get map_location_service_disabled_content => _t('map_location_service_disabled_content');
  String get map_location_service_disabled_title => _t('map_location_service_disabled_title');
  String map_marker_for_images({required Object city, required Object country}) =>
      _t('map_marker_for_images', {'city': city, 'country': country});
  String get map_marker_with_image => _t('map_marker_with_image');
  String get map_no_location_permission_content => _t('map_no_location_permission_content');
  String get map_no_location_permission_title => _t('map_no_location_permission_title');
  String get map_settings => _t('map_settings');
  String get map_settings_dark_mode => _t('map_settings_dark_mode');
  String get map_settings_date_range_option_day => _t('map_settings_date_range_option_day');
  String map_settings_date_range_option_days({required Object days}) =>
      _t('map_settings_date_range_option_days', {'days': days});
  String get map_settings_date_range_option_year => _t('map_settings_date_range_option_year');
  String map_settings_date_range_option_years({required Object years}) =>
      _t('map_settings_date_range_option_years', {'years': years});
  String get map_settings_dialog_title => _t('map_settings_dialog_title');
  String get map_settings_include_show_archived => _t('map_settings_include_show_archived');
  String get map_settings_include_show_partners => _t('map_settings_include_show_partners');
  String get map_settings_only_show_favorites => _t('map_settings_only_show_favorites');
  String get map_settings_theme_settings => _t('map_settings_theme_settings');
  String get map_zoom_to_see_photos => _t('map_zoom_to_see_photos');
  String get mark_all_as_read => _t('mark_all_as_read');
  String get mark_as_read => _t('mark_as_read');
  String get marked_all_as_read => _t('marked_all_as_read');
  String get matches => _t('matches');
  String get matching_assets => _t('matching_assets');
  String get media_type => _t('media_type');
  String get memories => _t('memories');
  String get memories_all_caught_up => _t('memories_all_caught_up');
  String get memories_check_back_tomorrow => _t('memories_check_back_tomorrow');
  String get memories_setting_description => _t('memories_setting_description');
  String get memories_start_over => _t('memories_start_over');
  String get memories_swipe_to_close => _t('memories_swipe_to_close');
  String get memory => _t('memory');
  String memory_lane_title({required Object title}) => _t('memory_lane_title', {'title': title});
  String get menu => _t('menu');
  String get merge => _t('merge');
  String get merge_people => _t('merge_people');
  String get merge_people_limit => _t('merge_people_limit');
  String get merge_people_prompt => _t('merge_people_prompt');
  String get merge_people_successfully => _t('merge_people_successfully');
  String merged_people_count({required int count}) => _t('merged_people_count', {'count': count});
  String get minimize => _t('minimize');
  String get minute => _t('minute');
  String get minutes => _t('minutes');
  String get mirror_horizontal => _t('mirror_horizontal');
  String get mirror_vertical => _t('mirror_vertical');
  String get missing => _t('missing');
  String get mobile_app => _t('mobile_app');
  String get mobile_app_download_onboarding_note => _t('mobile_app_download_onboarding_note');
  String get model => _t('model');
  String get month => _t('month');
  String get monthly_title_text_date_format => _t('monthly_title_text_date_format');
  String get more => _t('more');
  String get move => _t('move');
  String get move_down => _t('move_down');
  String get move_off_locked_folder => _t('move_off_locked_folder');
  String get move_to => _t('move_to');
  String get move_to_device_trash => _t('move_to_device_trash');
  String move_to_lock_folder_action_prompt({required int count}) =>
      _t('move_to_lock_folder_action_prompt', {'count': count});
  String get move_to_locked_folder => _t('move_to_locked_folder');
  String get move_to_locked_folder_confirmation => _t('move_to_locked_folder_confirmation');
  String get move_up => _t('move_up');
  String moved_to_archive({required int count}) => _t('moved_to_archive', {'count': count});
  String moved_to_library({required int count}) => _t('moved_to_library', {'count': count});
  String get moved_to_trash => _t('moved_to_trash');
  String get multiselect_grid_edit_date_time_err_read_only => _t('multiselect_grid_edit_date_time_err_read_only');
  String get multiselect_grid_edit_gps_err_read_only => _t('multiselect_grid_edit_gps_err_read_only');
  String get mute_memories => _t('mute_memories');
  String get my_albums => _t('my_albums');
  String get name => _t('name');
  String get name_or_nickname => _t('name_or_nickname');
  String get name_required => _t('name_required');
  String get navigate => _t('navigate');
  String get navigate_to_time => _t('navigate_to_time');
  String get network_requirement_photos_upload => _t('network_requirement_photos_upload');
  String get network_requirement_videos_upload => _t('network_requirement_videos_upload');
  String get network_requirements => _t('network_requirements');
  String get network_requirements_updated => _t('network_requirements_updated');
  String get networking_settings => _t('networking_settings');
  String get networking_subtitle => _t('networking_subtitle');
  String get never => _t('never');
  String get new_album => _t('new_album');
  String get new_api_key => _t('new_api_key');
  String get new_date_range => _t('new_date_range');
  String get new_password => _t('new_password');
  String get new_person => _t('new_person');
  String get new_pin_code => _t('new_pin_code');
  String get new_pin_code_subtitle => _t('new_pin_code_subtitle');
  String get new_timeline => _t('new_timeline');
  String get new_update => _t('new_update');
  String get new_user_created => _t('new_user_created');
  String get new_version_available => _t('new_version_available');
  String get newest_first => _t('newest_first');
  String get next => _t('next');
  String get next_memory => _t('next_memory');
  String get no => _t('no');
  String get no_actions_added => _t('no_actions_added');
  String get no_albums_found => _t('no_albums_found');
  String get no_albums_message => _t('no_albums_message');
  String get no_albums_with_name_yet => _t('no_albums_with_name_yet');
  String get no_albums_yet => _t('no_albums_yet');
  String get no_archived_assets_message => _t('no_archived_assets_message');
  String get no_assets_message => _t('no_assets_message');
  String get no_assets_to_show => _t('no_assets_to_show');
  String get no_cast_devices_found => _t('no_cast_devices_found');
  String get no_checksum_local => _t('no_checksum_local');
  String get no_checksum_remote => _t('no_checksum_remote');
  String get no_configuration_needed => _t('no_configuration_needed');
  String get no_devices => _t('no_devices');
  String get no_duplicates_found => _t('no_duplicates_found');
  String get no_exif_info_available => _t('no_exif_info_available');
  String get no_explore_results_message => _t('no_explore_results_message');
  String get no_favorites_message => _t('no_favorites_message');
  String get no_filters_added => _t('no_filters_added');
  String get no_libraries_message => _t('no_libraries_message');
  String get no_local_assets_found => _t('no_local_assets_found');
  String get no_location_set => _t('no_location_set');
  String get no_locked_photos_message => _t('no_locked_photos_message');
  String get no_name => _t('no_name');
  String get no_notifications => _t('no_notifications');
  String get no_people_found => _t('no_people_found');
  String get no_places => _t('no_places');
  String get no_remote_assets_found => _t('no_remote_assets_found');
  String get no_results => _t('no_results');
  String get no_results_description => _t('no_results_description');
  String get no_shared_albums_message => _t('no_shared_albums_message');
  String get no_uploads_in_progress => _t('no_uploads_in_progress');
  String get none => _t('none');
  String get not_allowed => _t('not_allowed');
  String get not_available => _t('not_available');
  String get not_in_any_album => _t('not_in_any_album');
  String get not_selected => _t('not_selected');
  String get notes => _t('notes');
  String get nothing_here_yet => _t('nothing_here_yet');
  String get notification_permission_dialog_content => _t('notification_permission_dialog_content');
  String get notification_permission_list_tile_content => _t('notification_permission_list_tile_content');
  String get notification_permission_list_tile_enable_button => _t('notification_permission_list_tile_enable_button');
  String get notification_permission_list_tile_title => _t('notification_permission_list_tile_title');
  String get notification_toggle_setting_description => _t('notification_toggle_setting_description');
  String get notifications => _t('notifications');
  String get notifications_setting_description => _t('notifications_setting_description');
  String get oauth => _t('oauth');
  String get obtainium_configurator => _t('obtainium_configurator');
  String get obtainium_configurator_instructions => _t('obtainium_configurator_instructions');
  String get ocr => _t('ocr');
  String get official_immich_resources => _t('official_immich_resources');
  String get offline => _t('offline');
  String get offset => _t('offset');
  String get ok => _t('ok');
  String get oldest_first => _t('oldest_first');
  String get on_this_device => _t('on_this_device');
  String get onboarding => _t('onboarding');
  String get onboarding_locale_description => _t('onboarding_locale_description');
  String get onboarding_privacy_description => _t('onboarding_privacy_description');
  String get onboarding_server_welcome_description => _t('onboarding_server_welcome_description');
  String get onboarding_theme_description => _t('onboarding_theme_description');
  String get onboarding_user_welcome_description => _t('onboarding_user_welcome_description');
  String onboarding_welcome_user({required Object user}) => _t('onboarding_welcome_user', {'user': user});
  String get online => _t('online');
  String get only_favorites => _t('only_favorites');
  String get open => _t('open');
  String get open_calendar => _t('open_calendar');
  String get open_in_browser => _t('open_in_browser');
  String get open_in_map_view => _t('open_in_map_view');
  String get open_in_openstreetmap => _t('open_in_openstreetmap');
  String get open_the_search_filters => _t('open_the_search_filters');
  String get options => _t('options');
  String get or => _t('or');
  String get organize_into_albums => _t('organize_into_albums');
  String get organize_into_albums_description => _t('organize_into_albums_description');
  String get organize_your_library => _t('organize_your_library');
  String get original => _t('original');
  String get other => _t('other');
  String get other_devices => _t('other_devices');
  String get other_entities => _t('other_entities');
  String get other_variables => _t('other_variables');
  String get owned => _t('owned');
  String get owner => _t('owner');
  String get page => _t('page');
  String get partner => _t('partner');
  String partner_can_access({required Object partner}) => _t('partner_can_access', {'partner': partner});
  String get partner_can_access_assets => _t('partner_can_access_assets');
  String get partner_can_access_location => _t('partner_can_access_location');
  String partner_list_user_photos({required Object user}) => _t('partner_list_user_photos', {'user': user});
  String get partner_list_view_all => _t('partner_list_view_all');
  String get partner_page_empty_message => _t('partner_page_empty_message');
  String get partner_page_no_more_users => _t('partner_page_no_more_users');
  String get partner_page_partner_add_failed => _t('partner_page_partner_add_failed');
  String get partner_page_select_partner => _t('partner_page_select_partner');
  String get partner_page_shared_to_title => _t('partner_page_shared_to_title');
  String partner_page_stop_sharing_content({required Object partner}) =>
      _t('partner_page_stop_sharing_content', {'partner': partner});
  String get partner_sharing => _t('partner_sharing');
  String get partners => _t('partners');
  String get password => _t('password');
  String get password_does_not_match => _t('password_does_not_match');
  String get password_required => _t('password_required');
  String get password_reset_success => _t('password_reset_success');
  late final past_durations = _PastDurationsTranslations._(_context);
  String get path => _t('path');
  String get pattern => _t('pattern');
  String get pause => _t('pause');
  String get pause_memories => _t('pause_memories');
  String get paused => _t('paused');
  String get pending => _t('pending');
  String get people => _t('people');
  String people_edits_count({required int count}) => _t('people_edits_count', {'count': count});
  String get people_feature_description => _t('people_feature_description');
  String people_selected({required int count}) => _t('people_selected', {'count': count});
  String get people_sidebar_description => _t('people_sidebar_description');
  String get permanent_deletion_warning => _t('permanent_deletion_warning');
  String get permanent_deletion_warning_setting_description => _t('permanent_deletion_warning_setting_description');
  String get permanently_delete => _t('permanently_delete');
  String permanently_delete_assets_count({required int count}) =>
      _t('permanently_delete_assets_count', {'count': count});
  String permanently_delete_assets_prompt({required int count}) =>
      _t('permanently_delete_assets_prompt', {'count': count});
  String get permanently_deleted_asset => _t('permanently_deleted_asset');
  String permanently_deleted_assets_count({required int count}) =>
      _t('permanently_deleted_assets_count', {'count': count});
  String get permission => _t('permission');
  String get permission_empty => _t('permission_empty');
  String get permission_onboarding_back => _t('permission_onboarding_back');
  String get permission_onboarding_continue_anyway => _t('permission_onboarding_continue_anyway');
  String get permission_onboarding_get_started => _t('permission_onboarding_get_started');
  String get permission_onboarding_go_to_settings => _t('permission_onboarding_go_to_settings');
  String get permission_onboarding_permission_denied => _t('permission_onboarding_permission_denied');
  String get permission_onboarding_permission_granted => _t('permission_onboarding_permission_granted');
  String get permission_onboarding_permission_limited => _t('permission_onboarding_permission_limited');
  String get permission_onboarding_request => _t('permission_onboarding_request');
  String get person => _t('person');
  String person_age_months({required int months}) => _t('person_age_months', {'months': months});
  String person_age_year_months({required int months}) => _t('person_age_year_months', {'months': months});
  String person_age_years({required int years}) => _t('person_age_years', {'years': years});
  String person_birthdate({required Object date}) => _t('person_birthdate', {'date': date});
  String person_hidden({required bool hidden, required Object name}) =>
      _t('person_hidden', {'hidden': hidden, 'name': name});
  String get person_recognized => _t('person_recognized');
  String get person_selected => _t('person_selected');
  String get photo_shared_all_users => _t('photo_shared_all_users');
  String get photos => _t('photos');
  String get photos_and_videos => _t('photos_and_videos');
  String photos_count({required int count}) => _t('photos_count', {'count': count});
  String get photos_from_previous_years => _t('photos_from_previous_years');
  String get photos_only => _t('photos_only');
  String get pick_a_location => _t('pick_a_location');
  String get pick_custom_range => _t('pick_custom_range');
  String get pick_date_range => _t('pick_date_range');
  String get pin_code_changed_successfully => _t('pin_code_changed_successfully');
  String get pin_code_reset_successfully => _t('pin_code_reset_successfully');
  String get pin_code_setup_successfully => _t('pin_code_setup_successfully');
  String get pin_verification => _t('pin_verification');
  String get place => _t('place');
  String get places => _t('places');
  String places_count({required int count}) => _t('places_count', {'count': count});
  String get play => _t('play');
  String get play_memories => _t('play_memories');
  String get play_motion_photo => _t('play_motion_photo');
  String get play_or_pause_video => _t('play_or_pause_video');
  String get play_original_video => _t('play_original_video');
  String get play_original_video_setting_description => _t('play_original_video_setting_description');
  String get play_transcoded_video => _t('play_transcoded_video');
  String get please_auth_to_access => _t('please_auth_to_access');
  String get port => _t('port');
  String get preferences_settings_subtitle => _t('preferences_settings_subtitle');
  String get preferences_settings_title => _t('preferences_settings_title');
  String get preparing => _t('preparing');
  String get preset => _t('preset');
  String get preview => _t('preview');
  String get previous => _t('previous');
  String get previous_memory => _t('previous_memory');
  String get previous_or_next_day => _t('previous_or_next_day');
  String get previous_or_next_month => _t('previous_or_next_month');
  String get previous_or_next_photo => _t('previous_or_next_photo');
  String get previous_or_next_year => _t('previous_or_next_year');
  String get primary => _t('primary');
  String get privacy => _t('privacy');
  String get profile => _t('profile');
  String get profile_drawer_app_logs => _t('profile_drawer_app_logs');
  String get profile_drawer_client_server_up_to_date => _t('profile_drawer_client_server_up_to_date');
  String get profile_drawer_github => _t('profile_drawer_github');
  String get profile_drawer_readonly_mode => _t('profile_drawer_readonly_mode');
  String profile_image_of_user({required Object user}) => _t('profile_image_of_user', {'user': user});
  String get profile_picture_set => _t('profile_picture_set');
  String get public_album => _t('public_album');
  String get public_share => _t('public_share');
  String get purchase_account_info => _t('purchase_account_info');
  String get purchase_activated_subtitle => _t('purchase_activated_subtitle');
  String purchase_activated_time({required Object date}) => _t('purchase_activated_time', {'date': date});
  String get purchase_activated_title => _t('purchase_activated_title');
  String get purchase_button_activate => _t('purchase_button_activate');
  String get purchase_button_buy => _t('purchase_button_buy');
  String get purchase_button_buy_immich => _t('purchase_button_buy_immich');
  String get purchase_button_never_show_again => _t('purchase_button_never_show_again');
  String get purchase_button_reminder => _t('purchase_button_reminder');
  String get purchase_button_remove_key => _t('purchase_button_remove_key');
  String get purchase_button_select => _t('purchase_button_select');
  String get purchase_failed_activation => _t('purchase_failed_activation');
  String get purchase_individual_description_1 => _t('purchase_individual_description_1');
  String get purchase_individual_description_2 => _t('purchase_individual_description_2');
  String get purchase_individual_title => _t('purchase_individual_title');
  String get purchase_input_suggestion => _t('purchase_input_suggestion');
  String get purchase_license_subtitle => _t('purchase_license_subtitle');
  String get purchase_lifetime_description => _t('purchase_lifetime_description');
  String get purchase_option_title => _t('purchase_option_title');
  String get purchase_panel_info_1 => _t('purchase_panel_info_1');
  String get purchase_panel_info_2 => _t('purchase_panel_info_2');
  String get purchase_panel_title => _t('purchase_panel_title');
  String get purchase_per_server => _t('purchase_per_server');
  String get purchase_per_user => _t('purchase_per_user');
  String get purchase_remove_product_key => _t('purchase_remove_product_key');
  String get purchase_remove_product_key_prompt => _t('purchase_remove_product_key_prompt');
  String get purchase_remove_server_product_key => _t('purchase_remove_server_product_key');
  String get purchase_remove_server_product_key_prompt => _t('purchase_remove_server_product_key_prompt');
  String get purchase_server_description_1 => _t('purchase_server_description_1');
  String get purchase_server_description_2 => _t('purchase_server_description_2');
  String get purchase_server_title => _t('purchase_server_title');
  String get purchase_settings_server_activated => _t('purchase_settings_server_activated');
  String get query_asset_id => _t('query_asset_id');
  String queue_status({required int count, required int total}) => _t('queue_status', {'count': count, 'total': total});
  String get rate_asset => _t('rate_asset');
  String get rating => _t('rating');
  String get rating_clear => _t('rating_clear');
  String rating_count({required int count}) => _t('rating_count', {'count': count});
  String get rating_description => _t('rating_description');
  String get reaction_options => _t('reaction_options');
  String get read_changelog => _t('read_changelog');
  String get readonly_mode_disabled => _t('readonly_mode_disabled');
  String get readonly_mode_enabled => _t('readonly_mode_enabled');
  String get ready_for_upload => _t('ready_for_upload');
  String get reassign => _t('reassign');
  String reassigned_assets_to_existing_person({required int count, required String name}) =>
      _t('reassigned_assets_to_existing_person', {'count': count, 'name': name});
  String reassigned_assets_to_new_person({required int count}) =>
      _t('reassigned_assets_to_new_person', {'count': count});
  String get reassing_hint => _t('reassing_hint');
  String get recent => _t('recent');
  String get recent_albums => _t('recent_albums');
  String get recent_searches => _t('recent_searches');
  String get recently_added => _t('recently_added');
  String get recently_added_page_title => _t('recently_added_page_title');
  String get recently_taken => _t('recently_taken');
  String get recently_taken_page_title => _t('recently_taken_page_title');
  String get refresh => _t('refresh');
  String get refresh_encoded_videos => _t('refresh_encoded_videos');
  String get refresh_faces => _t('refresh_faces');
  String get refresh_metadata => _t('refresh_metadata');
  String get refresh_thumbnails => _t('refresh_thumbnails');
  String get refreshed => _t('refreshed');
  String get refreshes_every_file => _t('refreshes_every_file');
  String get refreshing_encoded_video => _t('refreshing_encoded_video');
  String get refreshing_faces => _t('refreshing_faces');
  String get refreshing_metadata => _t('refreshing_metadata');
  String get regenerating_thumbnails => _t('regenerating_thumbnails');
  String get remote => _t('remote');
  String get remote_assets => _t('remote_assets');
  String get remote_media_summary => _t('remote_media_summary');
  String get remove => _t('remove');
  String remove_assets_album_confirmation({required int count}) =>
      _t('remove_assets_album_confirmation', {'count': count});
  String remove_assets_shared_link_confirmation({required int count}) =>
      _t('remove_assets_shared_link_confirmation', {'count': count});
  String get remove_assets_title => _t('remove_assets_title');
  String get remove_custom_date_range => _t('remove_custom_date_range');
  String get remove_deleted_assets => _t('remove_deleted_assets');
  String get remove_from_album => _t('remove_from_album');
  String remove_from_album_action_prompt({required int count}) =>
      _t('remove_from_album_action_prompt', {'count': count});
  String get remove_from_favorites => _t('remove_from_favorites');
  String remove_from_lock_folder_action_prompt({required int count}) =>
      _t('remove_from_lock_folder_action_prompt', {'count': count});
  String get remove_from_locked_folder => _t('remove_from_locked_folder');
  String get remove_from_locked_folder_confirmation => _t('remove_from_locked_folder_confirmation');
  String get remove_from_shared_link => _t('remove_from_shared_link');
  String get remove_memory => _t('remove_memory');
  String get remove_photo_from_memory => _t('remove_photo_from_memory');
  String get remove_tag => _t('remove_tag');
  String get remove_url => _t('remove_url');
  String get remove_user => _t('remove_user');
  String removed_api_key({required Object name}) => _t('removed_api_key', {'name': name});
  String get removed_from_archive => _t('removed_from_archive');
  String get removed_from_favorites => _t('removed_from_favorites');
  String removed_from_favorites_count({required int count}) => _t('removed_from_favorites_count', {'count': count});
  String get removed_memory => _t('removed_memory');
  String get removed_photo_from_memory => _t('removed_photo_from_memory');
  String removed_tagged_assets({required int count}) => _t('removed_tagged_assets', {'count': count});
  String get rename => _t('rename');
  String get repair => _t('repair');
  String get repair_no_results_message => _t('repair_no_results_message');
  String get replace_with_upload => _t('replace_with_upload');
  String get repository => _t('repository');
  String get require_password => _t('require_password');
  String get require_user_to_change_password_on_first_login => _t('require_user_to_change_password_on_first_login');
  String get rescan => _t('rescan');
  String get reset => _t('reset');
  String get reset_password => _t('reset_password');
  String get reset_people_visibility => _t('reset_people_visibility');
  String get reset_pin_code => _t('reset_pin_code');
  String get reset_pin_code_description => _t('reset_pin_code_description');
  String get reset_pin_code_success => _t('reset_pin_code_success');
  String get reset_pin_code_with_password => _t('reset_pin_code_with_password');
  String get reset_sqlite => _t('reset_sqlite');
  String get reset_sqlite_clear_app_data => _t('reset_sqlite_clear_app_data');
  String get reset_sqlite_confirmation => _t('reset_sqlite_confirmation');
  String get reset_sqlite_confirmation_note => _t('reset_sqlite_confirmation_note');
  String get reset_sqlite_done => _t('reset_sqlite_done');
  String get reset_sqlite_success => _t('reset_sqlite_success');
  String get reset_to_default => _t('reset_to_default');
  String get resolution => _t('resolution');
  String get resolve_duplicates => _t('resolve_duplicates');
  String get resolved_all_duplicates => _t('resolved_all_duplicates');
  String get restore => _t('restore');
  String get restore_all => _t('restore_all');
  String restore_trash_action_prompt({required int count}) => _t('restore_trash_action_prompt', {'count': count});
  String get restore_user => _t('restore_user');
  String get restored_asset => _t('restored_asset');
  String get resume => _t('resume');
  String resume_paused_jobs({required int count}) => _t('resume_paused_jobs', {'count': count});
  String get retry_upload => _t('retry_upload');
  String get review_duplicates => _t('review_duplicates');
  String get review_large_files => _t('review_large_files');
  String get role => _t('role');
  String get role_editor => _t('role_editor');
  String get role_viewer => _t('role_viewer');
  String get running => _t('running');
  String get save => _t('save');
  String get save_to_gallery => _t('save_to_gallery');
  String get saved => _t('saved');
  String get saved_api_key => _t('saved_api_key');
  String get saved_profile => _t('saved_profile');
  String get saved_settings => _t('saved_settings');
  String get say_something => _t('say_something');
  String get scaffold_body_error_occurred => _t('scaffold_body_error_occurred');
  String get scaffold_body_error_unrecoverable => _t('scaffold_body_error_unrecoverable');
  String get scan => _t('scan');
  String get scan_all_libraries => _t('scan_all_libraries');
  String get scan_library => _t('scan_library');
  String get scan_settings => _t('scan_settings');
  String get scanning => _t('scanning');
  String get scanning_for_album => _t('scanning_for_album');
  String get search => _t('search');
  String get search_albums => _t('search_albums');
  String get search_by_context => _t('search_by_context');
  String get search_by_description => _t('search_by_description');
  String get search_by_description_example => _t('search_by_description_example');
  String get search_by_filename => _t('search_by_filename');
  String get search_by_filename_example => _t('search_by_filename_example');
  String get search_by_ocr => _t('search_by_ocr');
  String get search_by_ocr_example => _t('search_by_ocr_example');
  String get search_camera_lens_model => _t('search_camera_lens_model');
  String get search_camera_make => _t('search_camera_make');
  String get search_camera_model => _t('search_camera_model');
  String get search_city => _t('search_city');
  String get search_country => _t('search_country');
  String get search_filter_apply => _t('search_filter_apply');
  String get search_filter_camera_title => _t('search_filter_camera_title');
  String get search_filter_date => _t('search_filter_date');
  String search_filter_date_interval({required Object start, required Object end}) =>
      _t('search_filter_date_interval', {'start': start, 'end': end});
  String get search_filter_date_title => _t('search_filter_date_title');
  String get search_filter_display_option_not_in_album => _t('search_filter_display_option_not_in_album');
  String get search_filter_display_options => _t('search_filter_display_options');
  String get search_filter_filename => _t('search_filter_filename');
  String get search_filter_location => _t('search_filter_location');
  String get search_filter_location_title => _t('search_filter_location_title');
  String get search_filter_media_type => _t('search_filter_media_type');
  String get search_filter_media_type_title => _t('search_filter_media_type_title');
  String get search_filter_ocr => _t('search_filter_ocr');
  String get search_filter_people_title => _t('search_filter_people_title');
  String get search_filter_star_rating => _t('search_filter_star_rating');
  String get search_filter_tags_title => _t('search_filter_tags_title');
  String get search_for => _t('search_for');
  String get search_for_existing_person => _t('search_for_existing_person');
  String get search_no_more_result => _t('search_no_more_result');
  String get search_no_people => _t('search_no_people');
  String search_no_people_named({required Object name}) => _t('search_no_people_named', {'name': name});
  String get search_no_result => _t('search_no_result');
  String get search_options => _t('search_options');
  String get search_page_categories => _t('search_page_categories');
  String get search_page_motion_photos => _t('search_page_motion_photos');
  String get search_page_no_objects => _t('search_page_no_objects');
  String get search_page_no_places => _t('search_page_no_places');
  String get search_page_screenshots => _t('search_page_screenshots');
  String get search_page_search_photos_videos => _t('search_page_search_photos_videos');
  String get search_page_selfies => _t('search_page_selfies');
  String get search_page_things => _t('search_page_things');
  String get search_page_view_all_button => _t('search_page_view_all_button');
  String get search_page_your_activity => _t('search_page_your_activity');
  String get search_page_your_map => _t('search_page_your_map');
  String get search_people => _t('search_people');
  String get search_places => _t('search_places');
  String get search_rating => _t('search_rating');
  String get search_result_page_new_search_hint => _t('search_result_page_new_search_hint');
  String get search_settings => _t('search_settings');
  String get search_state => _t('search_state');
  String get search_suggestion_list_smart_search_hint_1 => _t('search_suggestion_list_smart_search_hint_1');
  String get search_suggestion_list_smart_search_hint_2 => _t('search_suggestion_list_smart_search_hint_2');
  String get search_tags => _t('search_tags');
  String get search_timezone => _t('search_timezone');
  String get search_type => _t('search_type');
  String get search_your_photos => _t('search_your_photos');
  String get searching_locales => _t('searching_locales');
  String get second => _t('second');
  String get see_all_people => _t('see_all_people');
  String get select => _t('select');
  String get select_album => _t('select_album');
  String get select_album_cover => _t('select_album_cover');
  String get select_albums => _t('select_albums');
  String get select_all => _t('select_all');
  String get select_all_duplicates => _t('select_all_duplicates');
  String select_all_in({required Object group}) => _t('select_all_in', {'group': group});
  String get select_avatar_color => _t('select_avatar_color');
  String select_count({required int count}) => _t('select_count', {'count': count});
  String get select_cutoff_date => _t('select_cutoff_date');
  String get select_face => _t('select_face');
  String get select_featured_photo => _t('select_featured_photo');
  String get select_from_computer => _t('select_from_computer');
  String get select_keep_all => _t('select_keep_all');
  String get select_library_owner => _t('select_library_owner');
  String get select_new_face => _t('select_new_face');
  String get select_people => _t('select_people');
  String get select_person => _t('select_person');
  String get select_person_to_tag => _t('select_person_to_tag');
  String get select_photos => _t('select_photos');
  String get select_trash_all => _t('select_trash_all');
  String get select_user_for_sharing_page_err_album => _t('select_user_for_sharing_page_err_album');
  String get selected => _t('selected');
  String selected_count({required int count}) => _t('selected_count', {'count': count});
  String get selected_gps_coordinates => _t('selected_gps_coordinates');
  String get send_message => _t('send_message');
  String get send_welcome_email => _t('send_welcome_email');
  String get server_endpoint => _t('server_endpoint');
  String get server_info_box_app_version => _t('server_info_box_app_version');
  String get server_info_box_server_url => _t('server_info_box_server_url');
  String get server_offline => _t('server_offline');
  String get server_online => _t('server_online');
  String get server_privacy => _t('server_privacy');
  String get server_restarting_description => _t('server_restarting_description');
  String get server_restarting_title => _t('server_restarting_title');
  String get server_stats => _t('server_stats');
  String get server_update_available => _t('server_update_available');
  String get server_version => _t('server_version');
  String get set$ => _t('set');
  String get set_as_album_cover => _t('set_as_album_cover');
  String get set_as_featured_photo => _t('set_as_featured_photo');
  String get set_as_profile_picture => _t('set_as_profile_picture');
  String get set_date_of_birth => _t('set_date_of_birth');
  String get set_profile_picture => _t('set_profile_picture');
  String get set_slideshow_to_fullscreen => _t('set_slideshow_to_fullscreen');
  String get set_stack_primary_asset => _t('set_stack_primary_asset');
  String get setting_image_navigation_enable_subtitle => _t('setting_image_navigation_enable_subtitle');
  String get setting_image_navigation_enable_title => _t('setting_image_navigation_enable_title');
  String get setting_image_navigation_title => _t('setting_image_navigation_title');
  String get setting_image_viewer_help => _t('setting_image_viewer_help');
  String get setting_image_viewer_original_subtitle => _t('setting_image_viewer_original_subtitle');
  String get setting_image_viewer_original_title => _t('setting_image_viewer_original_title');
  String get setting_image_viewer_preview_subtitle => _t('setting_image_viewer_preview_subtitle');
  String get setting_image_viewer_preview_title => _t('setting_image_viewer_preview_title');
  String get setting_image_viewer_title => _t('setting_image_viewer_title');
  String get setting_languages_apply => _t('setting_languages_apply');
  String get setting_languages_subtitle => _t('setting_languages_subtitle');
  String setting_notifications_notify_failures_grace_period({required Object duration}) =>
      _t('setting_notifications_notify_failures_grace_period', {'duration': duration});
  String setting_notifications_notify_hours({required int count}) =>
      _t('setting_notifications_notify_hours', {'count': count});
  String get setting_notifications_notify_immediately => _t('setting_notifications_notify_immediately');
  String setting_notifications_notify_minutes({required int count}) =>
      _t('setting_notifications_notify_minutes', {'count': count});
  String get setting_notifications_notify_never => _t('setting_notifications_notify_never');
  String setting_notifications_notify_seconds({required int count}) =>
      _t('setting_notifications_notify_seconds', {'count': count});
  String get setting_notifications_single_progress_subtitle => _t('setting_notifications_single_progress_subtitle');
  String get setting_notifications_single_progress_title => _t('setting_notifications_single_progress_title');
  String get setting_notifications_subtitle => _t('setting_notifications_subtitle');
  String get setting_notifications_total_progress_subtitle => _t('setting_notifications_total_progress_subtitle');
  String get setting_notifications_total_progress_title => _t('setting_notifications_total_progress_title');
  String get setting_video_viewer_auto_play_subtitle => _t('setting_video_viewer_auto_play_subtitle');
  String get setting_video_viewer_auto_play_title => _t('setting_video_viewer_auto_play_title');
  String get setting_video_viewer_looping_title => _t('setting_video_viewer_looping_title');
  String get setting_video_viewer_original_video_subtitle => _t('setting_video_viewer_original_video_subtitle');
  String get setting_video_viewer_original_video_title => _t('setting_video_viewer_original_video_title');
  String get settings => _t('settings');
  String get settings_require_restart => _t('settings_require_restart');
  String get settings_saved => _t('settings_saved');
  String get setup_pin_code => _t('setup_pin_code');
  String get share => _t('share');
  String share_action_prompt({required int count}) => _t('share_action_prompt', {'count': count});
  String get share_add_photos => _t('share_add_photos');
  String share_assets_selected({required int count}) => _t('share_assets_selected', {'count': count});
  String get share_dialog_preparing => _t('share_dialog_preparing');
  String get share_link => _t('share_link');
  String get shared => _t('shared');
  String get shared_album_activities_input_disable => _t('shared_album_activities_input_disable');
  String get shared_album_activity_remove_content => _t('shared_album_activity_remove_content');
  String get shared_album_activity_remove_title => _t('shared_album_activity_remove_title');
  String get shared_album_section_people_action_error => _t('shared_album_section_people_action_error');
  String get shared_album_section_people_action_leave => _t('shared_album_section_people_action_leave');
  String get shared_album_section_people_action_remove_user => _t('shared_album_section_people_action_remove_user');
  String get shared_album_section_people_title => _t('shared_album_section_people_title');
  String get shared_by => _t('shared_by');
  String shared_by_user({required Object user}) => _t('shared_by_user', {'user': user});
  String get shared_by_you => _t('shared_by_you');
  String shared_from_partner({required Object partner}) => _t('shared_from_partner', {'partner': partner});
  String shared_intent_upload_button_progress_text({required Object current, required int total}) =>
      _t('shared_intent_upload_button_progress_text', {'current': current, 'total': total});
  String get shared_link_app_bar_title => _t('shared_link_app_bar_title');
  String get shared_link_clipboard_copied_massage => _t('shared_link_clipboard_copied_massage');
  String shared_link_clipboard_text({required Object link, required Object password}) =>
      _t('shared_link_clipboard_text', {'link': link, 'password': password});
  String get shared_link_create_error => _t('shared_link_create_error');
  String get shared_link_custom_url_description => _t('shared_link_custom_url_description');
  String get shared_link_edit_description_hint => _t('shared_link_edit_description_hint');
  String get shared_link_edit_expire_after_option_day => _t('shared_link_edit_expire_after_option_day');
  String shared_link_edit_expire_after_option_days({required int count}) =>
      _t('shared_link_edit_expire_after_option_days', {'count': count});
  String get shared_link_edit_expire_after_option_hour => _t('shared_link_edit_expire_after_option_hour');
  String shared_link_edit_expire_after_option_hours({required int count}) =>
      _t('shared_link_edit_expire_after_option_hours', {'count': count});
  String get shared_link_edit_expire_after_option_minute => _t('shared_link_edit_expire_after_option_minute');
  String shared_link_edit_expire_after_option_minutes({required int count}) =>
      _t('shared_link_edit_expire_after_option_minutes', {'count': count});
  String shared_link_edit_expire_after_option_months({required int count}) =>
      _t('shared_link_edit_expire_after_option_months', {'count': count});
  String shared_link_edit_expire_after_option_year({required int count}) =>
      _t('shared_link_edit_expire_after_option_year', {'count': count});
  String get shared_link_edit_password_hint => _t('shared_link_edit_password_hint');
  String get shared_link_edit_submit_button => _t('shared_link_edit_submit_button');
  String get shared_link_error_server_url_fetch => _t('shared_link_error_server_url_fetch');
  String shared_link_expires_day({required int count}) => _t('shared_link_expires_day', {'count': count});
  String shared_link_expires_days({required int count}) => _t('shared_link_expires_days', {'count': count});
  String shared_link_expires_hour({required int count}) => _t('shared_link_expires_hour', {'count': count});
  String shared_link_expires_hours({required int count}) => _t('shared_link_expires_hours', {'count': count});
  String shared_link_expires_minute({required int count}) => _t('shared_link_expires_minute', {'count': count});
  String shared_link_expires_minutes({required int count}) => _t('shared_link_expires_minutes', {'count': count});
  String get shared_link_expires_never => _t('shared_link_expires_never');
  String shared_link_expires_second({required int count}) => _t('shared_link_expires_second', {'count': count});
  String shared_link_expires_seconds({required int count}) => _t('shared_link_expires_seconds', {'count': count});
  String get shared_link_individual_shared => _t('shared_link_individual_shared');
  String get shared_link_info_chip_metadata => _t('shared_link_info_chip_metadata');
  String get shared_link_manage_links => _t('shared_link_manage_links');
  String get shared_link_options => _t('shared_link_options');
  String get shared_link_password_description => _t('shared_link_password_description');
  String get shared_links => _t('shared_links');
  String get shared_links_description => _t('shared_links_description');
  String shared_photos_and_videos_count({required int assetCount}) =>
      _t('shared_photos_and_videos_count', {'assetCount': assetCount});
  String get shared_with_me => _t('shared_with_me');
  String shared_with_partner({required Object partner}) => _t('shared_with_partner', {'partner': partner});
  String get sharing => _t('sharing');
  String get sharing_enter_password => _t('sharing_enter_password');
  String get sharing_page_album => _t('sharing_page_album');
  String get sharing_page_description => _t('sharing_page_description');
  String get sharing_page_empty_list => _t('sharing_page_empty_list');
  String get sharing_sidebar_description => _t('sharing_sidebar_description');
  String get sharing_silver_appbar_create_shared_album => _t('sharing_silver_appbar_create_shared_album');
  String get sharing_silver_appbar_share_partner => _t('sharing_silver_appbar_share_partner');
  String get shift_to_permanent_delete => _t('shift_to_permanent_delete');
  String get show_album_options => _t('show_album_options');
  String get show_albums => _t('show_albums');
  String get show_all_people => _t('show_all_people');
  String get show_and_hide_people => _t('show_and_hide_people');
  String get show_file_location => _t('show_file_location');
  String get show_gallery => _t('show_gallery');
  String get show_hidden_people => _t('show_hidden_people');
  String get show_in_timeline => _t('show_in_timeline');
  String get show_in_timeline_setting_description => _t('show_in_timeline_setting_description');
  String get show_keyboard_shortcuts => _t('show_keyboard_shortcuts');
  String get show_metadata => _t('show_metadata');
  String get show_or_hide_info => _t('show_or_hide_info');
  String get show_password => _t('show_password');
  String get show_person_options => _t('show_person_options');
  String get show_progress_bar => _t('show_progress_bar');
  String get show_schema => _t('show_schema');
  String get show_search_options => _t('show_search_options');
  String get show_shared_links => _t('show_shared_links');
  String get show_slideshow_transition => _t('show_slideshow_transition');
  String get show_supporter_badge => _t('show_supporter_badge');
  String get show_supporter_badge_description => _t('show_supporter_badge_description');
  String get show_text_recognition => _t('show_text_recognition');
  String get show_text_search_menu => _t('show_text_search_menu');
  String get shuffle => _t('shuffle');
  String get sidebar => _t('sidebar');
  String get sidebar_display_description => _t('sidebar_display_description');
  String get sign_out => _t('sign_out');
  String get sign_up => _t('sign_up');
  String get size => _t('size');
  String get skip_to_content => _t('skip_to_content');
  String get skip_to_folders => _t('skip_to_folders');
  String get skip_to_tags => _t('skip_to_tags');
  String get slideshow => _t('slideshow');
  String get slideshow_repeat => _t('slideshow_repeat');
  String get slideshow_repeat_description => _t('slideshow_repeat_description');
  String get slideshow_settings => _t('slideshow_settings');
  String get sort_albums_by => _t('sort_albums_by');
  String get sort_created => _t('sort_created');
  String get sort_items => _t('sort_items');
  String get sort_modified => _t('sort_modified');
  String get sort_newest => _t('sort_newest');
  String get sort_oldest => _t('sort_oldest');
  String get sort_people_by_similarity => _t('sort_people_by_similarity');
  String get sort_recent => _t('sort_recent');
  String get sort_title => _t('sort_title');
  String get source => _t('source');
  String get stack => _t('stack');
  String stack_action_prompt({required int count}) => _t('stack_action_prompt', {'count': count});
  String get stack_duplicates => _t('stack_duplicates');
  String get stack_select_one_photo => _t('stack_select_one_photo');
  String get stack_selected_photos => _t('stack_selected_photos');
  String stacked_assets_count({required int count}) => _t('stacked_assets_count', {'count': count});
  String get stacktrace => _t('stacktrace');
  String get start => _t('start');
  String get start_date => _t('start_date');
  String get start_date_before_end_date => _t('start_date_before_end_date');
  String get state => _t('state');
  String get status => _t('status');
  String get stop_casting => _t('stop_casting');
  String get stop_motion_photo => _t('stop_motion_photo');
  String get stop_photo_sharing => _t('stop_photo_sharing');
  String stop_photo_sharing_description({required Object partner}) =>
      _t('stop_photo_sharing_description', {'partner': partner});
  String get stop_sharing_photos_with_user => _t('stop_sharing_photos_with_user');
  String get storage => _t('storage');
  String get storage_label => _t('storage_label');
  String get storage_quota => _t('storage_quota');
  String storage_usage({required Object used, required Object available}) =>
      _t('storage_usage', {'used': used, 'available': available});
  String get submit => _t('submit');
  String get success => _t('success');
  String get suggestions => _t('suggestions');
  String get sunrise_on_the_beach => _t('sunrise_on_the_beach');
  String get support => _t('support');
  String get support_and_feedback => _t('support_and_feedback');
  String get support_third_party_description => _t('support_third_party_description');
  String get supporter => _t('supporter');
  String get swap_merge_direction => _t('swap_merge_direction');
  String get sync$ => _t('sync');
  String get sync_albums => _t('sync_albums');
  String get sync_albums_manual_subtitle => _t('sync_albums_manual_subtitle');
  String get sync_local => _t('sync_local');
  String get sync_remote => _t('sync_remote');
  String get sync_status => _t('sync_status');
  String get sync_status_subtitle => _t('sync_status_subtitle');
  String get sync_upload_album_setting_subtitle => _t('sync_upload_album_setting_subtitle');
  String get tag => _t('tag');
  String get tag_assets => _t('tag_assets');
  String tag_created({required Object tag}) => _t('tag_created', {'tag': tag});
  String get tag_feature_description => _t('tag_feature_description');
  String get tag_not_found_question => _t('tag_not_found_question');
  String get tag_people => _t('tag_people');
  String tag_updated({required Object tag}) => _t('tag_updated', {'tag': tag});
  String tagged_assets({required int count}) => _t('tagged_assets', {'count': count});
  String get tags => _t('tags');
  String get tap_to_run_job => _t('tap_to_run_job');
  String get template => _t('template');
  String get text_recognition => _t('text_recognition');
  String get theme => _t('theme');
  String get theme_selection => _t('theme_selection');
  String get theme_selection_description => _t('theme_selection_description');
  String get theme_setting_asset_list_storage_indicator_title => _t('theme_setting_asset_list_storage_indicator_title');
  String theme_setting_asset_list_tiles_per_row_title({required int count}) =>
      _t('theme_setting_asset_list_tiles_per_row_title', {'count': count});
  String get theme_setting_colorful_interface_subtitle => _t('theme_setting_colorful_interface_subtitle');
  String get theme_setting_colorful_interface_title => _t('theme_setting_colorful_interface_title');
  String get theme_setting_image_viewer_quality_subtitle => _t('theme_setting_image_viewer_quality_subtitle');
  String get theme_setting_image_viewer_quality_title => _t('theme_setting_image_viewer_quality_title');
  String get theme_setting_primary_color_subtitle => _t('theme_setting_primary_color_subtitle');
  String get theme_setting_primary_color_title => _t('theme_setting_primary_color_title');
  String get theme_setting_system_primary_color_title => _t('theme_setting_system_primary_color_title');
  String get theme_setting_system_theme_switch => _t('theme_setting_system_theme_switch');
  String get theme_setting_theme_subtitle => _t('theme_setting_theme_subtitle');
  String get theme_setting_three_stage_loading_subtitle => _t('theme_setting_three_stage_loading_subtitle');
  String get theme_setting_three_stage_loading_title => _t('theme_setting_three_stage_loading_title');
  String get then => _t('then');
  String get they_will_be_merged_together => _t('they_will_be_merged_together');
  String get third_party_resources => _t('third_party_resources');
  String get time => _t('time');
  String get time_based_memories => _t('time_based_memories');
  String get time_based_memories_duration => _t('time_based_memories_duration');
  String get timeline => _t('timeline');
  String get timezone => _t('timezone');
  String get to_archive => _t('to_archive');
  String get to_change_password => _t('to_change_password');
  String get to_favorite => _t('to_favorite');
  String get to_login => _t('to_login');
  String get to_multi_select => _t('to_multi_select');
  String get to_parent => _t('to_parent');
  String get to_select => _t('to_select');
  String get to_trash => _t('to_trash');
  String get toggle_settings => _t('toggle_settings');
  String get toggle_theme_description => _t('toggle_theme_description');
  String get total => _t('total');
  String get total_usage => _t('total_usage');
  String get trash => _t('trash');
  String trash_action_prompt({required int count}) => _t('trash_action_prompt', {'count': count});
  String get trash_all => _t('trash_all');
  String trash_count({required int count}) => _t('trash_count', {'count': count});
  String get trash_delete_asset => _t('trash_delete_asset');
  String get trash_emptied => _t('trash_emptied');
  String get trash_no_results_message => _t('trash_no_results_message');
  String get trash_page_delete_all => _t('trash_page_delete_all');
  String get trash_page_empty_trash_dialog_content => _t('trash_page_empty_trash_dialog_content');
  String trash_page_info({required Object days}) => _t('trash_page_info', {'days': days});
  String get trash_page_no_assets => _t('trash_page_no_assets');
  String get trash_page_restore_all => _t('trash_page_restore_all');
  String get trash_page_select_assets_btn => _t('trash_page_select_assets_btn');
  String trash_page_title({required int count}) => _t('trash_page_title', {'count': count});
  String trashed_items_will_be_permanently_deleted_after({required int days}) =>
      _t('trashed_items_will_be_permanently_deleted_after', {'days': days});
  String get trigger => _t('trigger');
  String get trigger_asset_uploaded => _t('trigger_asset_uploaded');
  String get trigger_asset_uploaded_description => _t('trigger_asset_uploaded_description');
  String get trigger_description => _t('trigger_description');
  String get trigger_person_recognized => _t('trigger_person_recognized');
  String get trigger_person_recognized_description => _t('trigger_person_recognized_description');
  String get trigger_type => _t('trigger_type');
  String get troubleshoot => _t('troubleshoot');
  String get type => _t('type');
  String get unable_to_change_pin_code => _t('unable_to_change_pin_code');
  String get unable_to_check_version => _t('unable_to_check_version');
  String get unable_to_setup_pin_code => _t('unable_to_setup_pin_code');
  String get unarchive => _t('unarchive');
  String unarchive_action_prompt({required int count}) => _t('unarchive_action_prompt', {'count': count});
  String unarchived_count({required int count}) => _t('unarchived_count', {'count': count});
  String get undo => _t('undo');
  String get unfavorite => _t('unfavorite');
  String unfavorite_action_prompt({required int count}) => _t('unfavorite_action_prompt', {'count': count});
  String get unhide_person => _t('unhide_person');
  String get unknown => _t('unknown');
  String get unknown_country => _t('unknown_country');
  String get unknown_date => _t('unknown_date');
  String get unknown_year => _t('unknown_year');
  String get unlimited => _t('unlimited');
  String get unlink_motion_video => _t('unlink_motion_video');
  String get unlink_oauth => _t('unlink_oauth');
  String get unlinked_oauth_account => _t('unlinked_oauth_account');
  String get unmute_memories => _t('unmute_memories');
  String get unnamed_album => _t('unnamed_album');
  String get unnamed_album_delete_confirmation => _t('unnamed_album_delete_confirmation');
  String get unnamed_share => _t('unnamed_share');
  String get unsaved_change => _t('unsaved_change');
  String get unselect_all => _t('unselect_all');
  String get unselect_all_duplicates => _t('unselect_all_duplicates');
  String unselect_all_in({required Object group}) => _t('unselect_all_in', {'group': group});
  String get unstack => _t('unstack');
  String unstack_action_prompt({required int count}) => _t('unstack_action_prompt', {'count': count});
  String unstacked_assets_count({required int count}) => _t('unstacked_assets_count', {'count': count});
  String get unsupported_field_type => _t('unsupported_field_type');
  String unsupported_file_type({required Object file, required Object type}) =>
      _t('unsupported_file_type', {'file': file, 'type': type});
  String get untagged => _t('untagged');
  String get untitled_workflow => _t('untitled_workflow');
  String get up_next => _t('up_next');
  String update_location_action_prompt({required int count}) => _t('update_location_action_prompt', {'count': count});
  String get updated_at => _t('updated_at');
  String get updated_password => _t('updated_password');
  String get upload => _t('upload');
  String get upload_concurrency => _t('upload_concurrency');
  String get upload_details => _t('upload_details');
  String get upload_dialog_info => _t('upload_dialog_info');
  String get upload_dialog_title => _t('upload_dialog_title');
  String upload_error_with_count({required int count}) => _t('upload_error_with_count', {'count': count});
  String upload_errors({required int count}) => _t('upload_errors', {'count': count});
  String get upload_finished => _t('upload_finished');
  String upload_progress({required int remaining, required int processed, required int total}) =>
      _t('upload_progress', {'remaining': remaining, 'processed': processed, 'total': total});
  String upload_skipped_duplicates({required int count}) => _t('upload_skipped_duplicates', {'count': count});
  String get upload_status_duplicates => _t('upload_status_duplicates');
  String get upload_status_errors => _t('upload_status_errors');
  String get upload_status_uploaded => _t('upload_status_uploaded');
  String get upload_success => _t('upload_success');
  String upload_to_immich({required int count}) => _t('upload_to_immich', {'count': count});
  String get uploading => _t('uploading');
  String get uploading_media => _t('uploading_media');
  String get url => _t('url');
  String get usage => _t('usage');
  String get use_biometric => _t('use_biometric');
  String get use_browser_locale => _t('use_browser_locale');
  String get use_browser_locale_description => _t('use_browser_locale_description');
  String get use_current_connection => _t('use_current_connection');
  String get use_custom_date_range => _t('use_custom_date_range');
  String get user => _t('user');
  String get user_has_been_deleted => _t('user_has_been_deleted');
  String get user_id => _t('user_id');
  String user_liked({required String type, required Object user}) => _t('user_liked', {'type': type, 'user': user});
  String get user_pin_code_settings => _t('user_pin_code_settings');
  String get user_pin_code_settings_description => _t('user_pin_code_settings_description');
  String get user_privacy => _t('user_privacy');
  String get user_purchase_settings => _t('user_purchase_settings');
  String get user_purchase_settings_description => _t('user_purchase_settings_description');
  String user_role_set({required Object user, required Object role}) =>
      _t('user_role_set', {'user': user, 'role': role});
  String get user_usage_detail => _t('user_usage_detail');
  String get user_usage_stats => _t('user_usage_stats');
  String get user_usage_stats_description => _t('user_usage_stats_description');
  String get username => _t('username');
  String get users => _t('users');
  String users_added_to_album_count({required int count}) => _t('users_added_to_album_count', {'count': count});
  String get utilities => _t('utilities');
  String get validate => _t('validate');
  String get validate_endpoint_error => _t('validate_endpoint_error');
  String get validation_error => _t('validation_error');
  String get variables => _t('variables');
  String get version => _t('version');
  String get version_announcement_closing => _t('version_announcement_closing');
  String get version_announcement_message => _t('version_announcement_message');
  String get version_history => _t('version_history');
  String version_history_item({required Object version, required Object date}) =>
      _t('version_history_item', {'version': version, 'date': date});
  String get video => _t('video');
  String get video_hover_setting => _t('video_hover_setting');
  String get video_hover_setting_description => _t('video_hover_setting_description');
  String get videos => _t('videos');
  String videos_count({required int count}) => _t('videos_count', {'count': count});
  String get videos_only => _t('videos_only');
  String get view => _t('view');
  String get view_album => _t('view_album');
  String get view_all => _t('view_all');
  String get view_all_users => _t('view_all_users');
  String get view_asset_owners => _t('view_asset_owners');
  String get view_details => _t('view_details');
  String get view_in_timeline => _t('view_in_timeline');
  String get view_link => _t('view_link');
  String get view_links => _t('view_links');
  String get view_name => _t('view_name');
  String get view_next_asset => _t('view_next_asset');
  String get view_previous_asset => _t('view_previous_asset');
  String get view_qr_code => _t('view_qr_code');
  String get view_similar_photos => _t('view_similar_photos');
  String get view_stack => _t('view_stack');
  String get view_user => _t('view_user');
  String get viewer_remove_from_stack => _t('viewer_remove_from_stack');
  String get viewer_stack_use_as_main_asset => _t('viewer_stack_use_as_main_asset');
  String get viewer_unstack => _t('viewer_unstack');
  String visibility_changed({required int count}) => _t('visibility_changed', {'count': count});
  String get visual => _t('visual');
  String get visual_builder => _t('visual_builder');
  String get waiting => _t('waiting');
  String waiting_count({required int count}) => _t('waiting_count', {'count': count});
  String get warning => _t('warning');
  String get week => _t('week');
  String get welcome => _t('welcome');
  String get welcome_to_immich => _t('welcome_to_immich');
  String get width => _t('width');
  String get wifi_name => _t('wifi_name');
  String get workflow_delete_prompt => _t('workflow_delete_prompt');
  String get workflow_deleted => _t('workflow_deleted');
  String get workflow_description => _t('workflow_description');
  String get workflow_info => _t('workflow_info');
  String get workflow_json => _t('workflow_json');
  String get workflow_json_help => _t('workflow_json_help');
  String get workflow_name => _t('workflow_name');
  String get workflow_navigation_prompt => _t('workflow_navigation_prompt');
  String get workflow_summary => _t('workflow_summary');
  String get workflow_update_success => _t('workflow_update_success');
  String get workflow_updated => _t('workflow_updated');
  String get workflows => _t('workflows');
  String get workflows_help_text => _t('workflows_help_text');
  String get wrong_pin_code => _t('wrong_pin_code');
  String get year => _t('year');
  String years_ago({required int years}) => _t('years_ago', {'years': years});
  String get yes => _t('yes');
  String get you_dont_have_any_shared_links => _t('you_dont_have_any_shared_links');
  String get your_wifi_name => _t('your_wifi_name');
  String get zero_to_clear_rating => _t('zero_to_clear_rating');
  String get zoom_image => _t('zoom_image');
  String get zoom_to_bounds => _t('zoom_to_bounds');
}

class _AdminTranslations extends _BaseTranslations {
  @override
  final BuildContext? _context;
  _AdminTranslations._(this._context);
  String get add_exclusion_pattern_description => _t('admin.add_exclusion_pattern_description');
  String get admin_user => _t('admin.admin_user');
  String get asset_offline_description => _t('admin.asset_offline_description');
  String get authentication_settings => _t('admin.authentication_settings');
  String get authentication_settings_description => _t('admin.authentication_settings_description');
  String get authentication_settings_disable_all => _t('admin.authentication_settings_disable_all');
  String get authentication_settings_reenable => _t('admin.authentication_settings_reenable');
  String get background_task_job => _t('admin.background_task_job');
  String get backup_database => _t('admin.backup_database');
  String get backup_database_enable_description => _t('admin.backup_database_enable_description');
  String get backup_keep_last_amount => _t('admin.backup_keep_last_amount');
  String get backup_onboarding_1_description => _t('admin.backup_onboarding_1_description');
  String get backup_onboarding_2_description => _t('admin.backup_onboarding_2_description');
  String get backup_onboarding_3_description => _t('admin.backup_onboarding_3_description');
  String get backup_onboarding_description => _t('admin.backup_onboarding_description');
  String get backup_onboarding_footer => _t('admin.backup_onboarding_footer');
  String get backup_onboarding_parts_title => _t('admin.backup_onboarding_parts_title');
  String get backup_onboarding_title => _t('admin.backup_onboarding_title');
  String get backup_settings => _t('admin.backup_settings');
  String get backup_settings_description => _t('admin.backup_settings_description');
  String cleared_jobs({required Object job}) => _t('admin.cleared_jobs', {'job': job});
  String get config_set_by_file => _t('admin.config_set_by_file');
  String confirm_delete_library({required Object library$}) =>
      _t('admin.confirm_delete_library', {'library': library$});
  String confirm_delete_library_assets({required int count}) =>
      _t('admin.confirm_delete_library_assets', {'count': count});
  String confirm_email_below({required Object email}) => _t('admin.confirm_email_below', {'email': email});
  String get confirm_reprocess_all_faces => _t('admin.confirm_reprocess_all_faces');
  String confirm_user_password_reset({required Object user}) => _t('admin.confirm_user_password_reset', {'user': user});
  String confirm_user_pin_code_reset({required Object user}) => _t('admin.confirm_user_pin_code_reset', {'user': user});
  String get copy_config_to_clipboard_description => _t('admin.copy_config_to_clipboard_description');
  String get create_job => _t('admin.create_job');
  String get cron_expression => _t('admin.cron_expression');
  String get cron_expression_description => _t('admin.cron_expression_description');
  String get cron_expression_presets => _t('admin.cron_expression_presets');
  String get disable_login => _t('admin.disable_login');
  String get duplicate_detection_job_description => _t('admin.duplicate_detection_job_description');
  String get exclusion_pattern_description => _t('admin.exclusion_pattern_description');
  String get export_config_as_json_description => _t('admin.export_config_as_json_description');
  String get external_libraries_page_description => _t('admin.external_libraries_page_description');
  String get face_detection => _t('admin.face_detection');
  String get face_detection_description => _t('admin.face_detection_description');
  String get facial_recognition_job_description => _t('admin.facial_recognition_job_description');
  String failed_job_command({required Object command, required Object job}) =>
      _t('admin.failed_job_command', {'command': command, 'job': job});
  String get force_delete_user_warning => _t('admin.force_delete_user_warning');
  String get image_format => _t('admin.image_format');
  String get image_format_description => _t('admin.image_format_description');
  String get image_fullsize_description => _t('admin.image_fullsize_description');
  String get image_fullsize_enabled => _t('admin.image_fullsize_enabled');
  String get image_fullsize_enabled_description => _t('admin.image_fullsize_enabled_description');
  String get image_fullsize_quality_description => _t('admin.image_fullsize_quality_description');
  String get image_fullsize_title => _t('admin.image_fullsize_title');
  String get image_prefer_embedded_preview => _t('admin.image_prefer_embedded_preview');
  String get image_prefer_embedded_preview_setting_description =>
      _t('admin.image_prefer_embedded_preview_setting_description');
  String get image_prefer_wide_gamut => _t('admin.image_prefer_wide_gamut');
  String get image_prefer_wide_gamut_setting_description => _t('admin.image_prefer_wide_gamut_setting_description');
  String get image_preview_description => _t('admin.image_preview_description');
  String get image_preview_quality_description => _t('admin.image_preview_quality_description');
  String get image_preview_title => _t('admin.image_preview_title');
  String get image_progressive => _t('admin.image_progressive');
  String get image_progressive_description => _t('admin.image_progressive_description');
  String get image_quality => _t('admin.image_quality');
  String get image_resolution => _t('admin.image_resolution');
  String get image_resolution_description => _t('admin.image_resolution_description');
  String get image_settings => _t('admin.image_settings');
  String get image_settings_description => _t('admin.image_settings_description');
  String get image_thumbnail_description => _t('admin.image_thumbnail_description');
  String get image_thumbnail_quality_description => _t('admin.image_thumbnail_quality_description');
  String get image_thumbnail_title => _t('admin.image_thumbnail_title');
  String get import_config_from_json_description => _t('admin.import_config_from_json_description');
  String job_concurrency({required Object job}) => _t('admin.job_concurrency', {'job': job});
  String get job_created => _t('admin.job_created');
  String get job_not_concurrency_safe => _t('admin.job_not_concurrency_safe');
  String get job_settings => _t('admin.job_settings');
  String get job_settings_description => _t('admin.job_settings_description');
  String jobs_delayed({required int jobCount}) => _t('admin.jobs_delayed', {'jobCount': jobCount});
  String jobs_failed({required int jobCount}) => _t('admin.jobs_failed', {'jobCount': jobCount});
  String get jobs_over_time => _t('admin.jobs_over_time');
  String library_created({required Object library$}) => _t('admin.library_created', {'library': library$});
  String get library_deleted => _t('admin.library_deleted');
  String get library_details => _t('admin.library_details');
  String get library_folder_description => _t('admin.library_folder_description');
  String get library_remove_exclusion_pattern_prompt => _t('admin.library_remove_exclusion_pattern_prompt');
  String get library_remove_folder_prompt => _t('admin.library_remove_folder_prompt');
  String get library_scanning => _t('admin.library_scanning');
  String get library_scanning_description => _t('admin.library_scanning_description');
  String get library_scanning_enable_description => _t('admin.library_scanning_enable_description');
  String get library_settings => _t('admin.library_settings');
  String get library_settings_description => _t('admin.library_settings_description');
  String get library_tasks_description => _t('admin.library_tasks_description');
  String get library_updated => _t('admin.library_updated');
  String get library_watching_enable_description => _t('admin.library_watching_enable_description');
  String get library_watching_settings => _t('admin.library_watching_settings');
  String get library_watching_settings_description => _t('admin.library_watching_settings_description');
  String get logging_enable_description => _t('admin.logging_enable_description');
  String get logging_level_description => _t('admin.logging_level_description');
  String get logging_settings => _t('admin.logging_settings');
  String get machine_learning_availability_checks => _t('admin.machine_learning_availability_checks');
  String get machine_learning_availability_checks_description =>
      _t('admin.machine_learning_availability_checks_description');
  String get machine_learning_availability_checks_enabled => _t('admin.machine_learning_availability_checks_enabled');
  String get machine_learning_availability_checks_interval => _t('admin.machine_learning_availability_checks_interval');
  String get machine_learning_availability_checks_interval_description =>
      _t('admin.machine_learning_availability_checks_interval_description');
  String get machine_learning_availability_checks_timeout => _t('admin.machine_learning_availability_checks_timeout');
  String get machine_learning_availability_checks_timeout_description =>
      _t('admin.machine_learning_availability_checks_timeout_description');
  String get machine_learning_clip_model => _t('admin.machine_learning_clip_model');
  String get machine_learning_clip_model_description => _t('admin.machine_learning_clip_model_description');
  String get machine_learning_duplicate_detection => _t('admin.machine_learning_duplicate_detection');
  String get machine_learning_duplicate_detection_enabled => _t('admin.machine_learning_duplicate_detection_enabled');
  String get machine_learning_duplicate_detection_enabled_description =>
      _t('admin.machine_learning_duplicate_detection_enabled_description');
  String get machine_learning_duplicate_detection_setting_description =>
      _t('admin.machine_learning_duplicate_detection_setting_description');
  String get machine_learning_enabled => _t('admin.machine_learning_enabled');
  String get machine_learning_enabled_description => _t('admin.machine_learning_enabled_description');
  String get machine_learning_facial_recognition => _t('admin.machine_learning_facial_recognition');
  String get machine_learning_facial_recognition_description =>
      _t('admin.machine_learning_facial_recognition_description');
  String get machine_learning_facial_recognition_model => _t('admin.machine_learning_facial_recognition_model');
  String get machine_learning_facial_recognition_model_description =>
      _t('admin.machine_learning_facial_recognition_model_description');
  String get machine_learning_facial_recognition_setting => _t('admin.machine_learning_facial_recognition_setting');
  String get machine_learning_facial_recognition_setting_description =>
      _t('admin.machine_learning_facial_recognition_setting_description');
  String get machine_learning_max_detection_distance => _t('admin.machine_learning_max_detection_distance');
  String get machine_learning_max_detection_distance_description =>
      _t('admin.machine_learning_max_detection_distance_description');
  String get machine_learning_max_recognition_distance => _t('admin.machine_learning_max_recognition_distance');
  String get machine_learning_max_recognition_distance_description =>
      _t('admin.machine_learning_max_recognition_distance_description');
  String get machine_learning_min_detection_score => _t('admin.machine_learning_min_detection_score');
  String get machine_learning_min_detection_score_description =>
      _t('admin.machine_learning_min_detection_score_description');
  String get machine_learning_min_recognized_faces => _t('admin.machine_learning_min_recognized_faces');
  String get machine_learning_min_recognized_faces_description =>
      _t('admin.machine_learning_min_recognized_faces_description');
  String get machine_learning_ocr => _t('admin.machine_learning_ocr');
  String get machine_learning_ocr_description => _t('admin.machine_learning_ocr_description');
  String get machine_learning_ocr_enabled => _t('admin.machine_learning_ocr_enabled');
  String get machine_learning_ocr_enabled_description => _t('admin.machine_learning_ocr_enabled_description');
  String get machine_learning_ocr_max_resolution => _t('admin.machine_learning_ocr_max_resolution');
  String get machine_learning_ocr_max_resolution_description =>
      _t('admin.machine_learning_ocr_max_resolution_description');
  String get machine_learning_ocr_min_detection_score => _t('admin.machine_learning_ocr_min_detection_score');
  String get machine_learning_ocr_min_detection_score_description =>
      _t('admin.machine_learning_ocr_min_detection_score_description');
  String get machine_learning_ocr_min_recognition_score => _t('admin.machine_learning_ocr_min_recognition_score');
  String get machine_learning_ocr_min_score_recognition_description =>
      _t('admin.machine_learning_ocr_min_score_recognition_description');
  String get machine_learning_ocr_model => _t('admin.machine_learning_ocr_model');
  String get machine_learning_ocr_model_description => _t('admin.machine_learning_ocr_model_description');
  String get machine_learning_settings => _t('admin.machine_learning_settings');
  String get machine_learning_settings_description => _t('admin.machine_learning_settings_description');
  String get machine_learning_smart_search => _t('admin.machine_learning_smart_search');
  String get machine_learning_smart_search_description => _t('admin.machine_learning_smart_search_description');
  String get machine_learning_smart_search_enabled => _t('admin.machine_learning_smart_search_enabled');
  String get machine_learning_smart_search_enabled_description =>
      _t('admin.machine_learning_smart_search_enabled_description');
  String get machine_learning_url_description => _t('admin.machine_learning_url_description');
  String get maintenance_delete_backup => _t('admin.maintenance_delete_backup');
  String get maintenance_delete_backup_description => _t('admin.maintenance_delete_backup_description');
  String get maintenance_delete_error => _t('admin.maintenance_delete_error');
  String get maintenance_restore_backup => _t('admin.maintenance_restore_backup');
  String get maintenance_restore_backup_description => _t('admin.maintenance_restore_backup_description');
  String get maintenance_restore_backup_different_version => _t('admin.maintenance_restore_backup_different_version');
  String get maintenance_restore_backup_unknown_version => _t('admin.maintenance_restore_backup_unknown_version');
  String get maintenance_restore_database_backup => _t('admin.maintenance_restore_database_backup');
  String get maintenance_restore_database_backup_description =>
      _t('admin.maintenance_restore_database_backup_description');
  String get maintenance_settings => _t('admin.maintenance_settings');
  String get maintenance_settings_description => _t('admin.maintenance_settings_description');
  String get maintenance_start => _t('admin.maintenance_start');
  String get maintenance_start_error => _t('admin.maintenance_start_error');
  String get maintenance_upload_backup => _t('admin.maintenance_upload_backup');
  String get maintenance_upload_backup_error => _t('admin.maintenance_upload_backup_error');
  String get manage_concurrency => _t('admin.manage_concurrency');
  String get manage_concurrency_description => _t('admin.manage_concurrency_description');
  String get manage_log_settings => _t('admin.manage_log_settings');
  String get map_dark_style => _t('admin.map_dark_style');
  String get map_enable_description => _t('admin.map_enable_description');
  String get map_gps_settings => _t('admin.map_gps_settings');
  String get map_gps_settings_description => _t('admin.map_gps_settings_description');
  String get map_implications => _t('admin.map_implications');
  String get map_light_style => _t('admin.map_light_style');
  String get map_manage_reverse_geocoding_settings => _t('admin.map_manage_reverse_geocoding_settings');
  String get map_reverse_geocoding => _t('admin.map_reverse_geocoding');
  String get map_reverse_geocoding_enable_description => _t('admin.map_reverse_geocoding_enable_description');
  String get map_reverse_geocoding_settings => _t('admin.map_reverse_geocoding_settings');
  String get map_settings => _t('admin.map_settings');
  String get map_settings_description => _t('admin.map_settings_description');
  String get map_style_description => _t('admin.map_style_description');
  String get memory_cleanup_job => _t('admin.memory_cleanup_job');
  String get memory_generate_job => _t('admin.memory_generate_job');
  String get metadata_extraction_job => _t('admin.metadata_extraction_job');
  String get metadata_extraction_job_description => _t('admin.metadata_extraction_job_description');
  String get metadata_faces_import_setting => _t('admin.metadata_faces_import_setting');
  String get metadata_faces_import_setting_description => _t('admin.metadata_faces_import_setting_description');
  String get metadata_settings => _t('admin.metadata_settings');
  String get metadata_settings_description => _t('admin.metadata_settings_description');
  String get migration_job => _t('admin.migration_job');
  String get migration_job_description => _t('admin.migration_job_description');
  String get nightly_tasks_cluster_faces_setting_description =>
      _t('admin.nightly_tasks_cluster_faces_setting_description');
  String get nightly_tasks_cluster_new_faces_setting => _t('admin.nightly_tasks_cluster_new_faces_setting');
  String get nightly_tasks_database_cleanup_setting => _t('admin.nightly_tasks_database_cleanup_setting');
  String get nightly_tasks_database_cleanup_setting_description =>
      _t('admin.nightly_tasks_database_cleanup_setting_description');
  String get nightly_tasks_generate_memories_setting => _t('admin.nightly_tasks_generate_memories_setting');
  String get nightly_tasks_generate_memories_setting_description =>
      _t('admin.nightly_tasks_generate_memories_setting_description');
  String get nightly_tasks_missing_thumbnails_setting => _t('admin.nightly_tasks_missing_thumbnails_setting');
  String get nightly_tasks_missing_thumbnails_setting_description =>
      _t('admin.nightly_tasks_missing_thumbnails_setting_description');
  String get nightly_tasks_settings => _t('admin.nightly_tasks_settings');
  String get nightly_tasks_settings_description => _t('admin.nightly_tasks_settings_description');
  String get nightly_tasks_start_time_setting => _t('admin.nightly_tasks_start_time_setting');
  String get nightly_tasks_start_time_setting_description => _t('admin.nightly_tasks_start_time_setting_description');
  String get nightly_tasks_sync_quota_usage_setting => _t('admin.nightly_tasks_sync_quota_usage_setting');
  String get nightly_tasks_sync_quota_usage_setting_description =>
      _t('admin.nightly_tasks_sync_quota_usage_setting_description');
  String get no_paths_added => _t('admin.no_paths_added');
  String get no_pattern_added => _t('admin.no_pattern_added');
  String get note_apply_storage_label_previous_assets => _t('admin.note_apply_storage_label_previous_assets');
  String get note_cannot_be_changed_later => _t('admin.note_cannot_be_changed_later');
  String get notification_email_from_address => _t('admin.notification_email_from_address');
  String get notification_email_from_address_description => _t('admin.notification_email_from_address_description');
  String get notification_email_host_description => _t('admin.notification_email_host_description');
  String get notification_email_ignore_certificate_errors => _t('admin.notification_email_ignore_certificate_errors');
  String get notification_email_ignore_certificate_errors_description =>
      _t('admin.notification_email_ignore_certificate_errors_description');
  String get notification_email_password_description => _t('admin.notification_email_password_description');
  String get notification_email_port_description => _t('admin.notification_email_port_description');
  String get notification_email_secure => _t('admin.notification_email_secure');
  String get notification_email_secure_description => _t('admin.notification_email_secure_description');
  String get notification_email_sent_test_email_button => _t('admin.notification_email_sent_test_email_button');
  String get notification_email_setting_description => _t('admin.notification_email_setting_description');
  String get notification_email_test_email => _t('admin.notification_email_test_email');
  String get notification_email_test_email_failed => _t('admin.notification_email_test_email_failed');
  String notification_email_test_email_sent({required Object email}) =>
      _t('admin.notification_email_test_email_sent', {'email': email});
  String get notification_email_username_description => _t('admin.notification_email_username_description');
  String get notification_enable_email_notifications => _t('admin.notification_enable_email_notifications');
  String get notification_settings => _t('admin.notification_settings');
  String get notification_settings_description => _t('admin.notification_settings_description');
  String get oauth_auto_launch => _t('admin.oauth_auto_launch');
  String get oauth_auto_launch_description => _t('admin.oauth_auto_launch_description');
  String get oauth_auto_register => _t('admin.oauth_auto_register');
  String get oauth_auto_register_description => _t('admin.oauth_auto_register_description');
  String get oauth_button_text => _t('admin.oauth_button_text');
  String get oauth_client_secret_description => _t('admin.oauth_client_secret_description');
  String get oauth_enable_description => _t('admin.oauth_enable_description');
  String get oauth_mobile_redirect_uri => _t('admin.oauth_mobile_redirect_uri');
  String get oauth_mobile_redirect_uri_override => _t('admin.oauth_mobile_redirect_uri_override');
  String oauth_mobile_redirect_uri_override_description({required Object callback}) =>
      _t('admin.oauth_mobile_redirect_uri_override_description', {'callback': callback});
  String get oauth_role_claim => _t('admin.oauth_role_claim');
  String get oauth_role_claim_description => _t('admin.oauth_role_claim_description');
  String get oauth_settings => _t('admin.oauth_settings');
  String get oauth_settings_description => _t('admin.oauth_settings_description');
  String get oauth_settings_more_details => _t('admin.oauth_settings_more_details');
  String get oauth_storage_label_claim => _t('admin.oauth_storage_label_claim');
  String get oauth_storage_label_claim_description => _t('admin.oauth_storage_label_claim_description');
  String get oauth_storage_quota_claim => _t('admin.oauth_storage_quota_claim');
  String get oauth_storage_quota_claim_description => _t('admin.oauth_storage_quota_claim_description');
  String get oauth_storage_quota_default => _t('admin.oauth_storage_quota_default');
  String get oauth_storage_quota_default_description => _t('admin.oauth_storage_quota_default_description');
  String get oauth_timeout => _t('admin.oauth_timeout');
  String get oauth_timeout_description => _t('admin.oauth_timeout_description');
  String get ocr_job_description => _t('admin.ocr_job_description');
  String get password_enable_description => _t('admin.password_enable_description');
  String get password_settings => _t('admin.password_settings');
  String get password_settings_description => _t('admin.password_settings_description');
  String get paths_validated_successfully => _t('admin.paths_validated_successfully');
  String get person_cleanup_job => _t('admin.person_cleanup_job');
  String get queue_details => _t('admin.queue_details');
  String get queues => _t('admin.queues');
  String get queues_page_description => _t('admin.queues_page_description');
  String get quota_size_gib => _t('admin.quota_size_gib');
  String get refreshing_all_libraries => _t('admin.refreshing_all_libraries');
  String get registration => _t('admin.registration');
  String get registration_description => _t('admin.registration_description');
  String get remove_failed_jobs => _t('admin.remove_failed_jobs');
  String get require_password_change_on_login => _t('admin.require_password_change_on_login');
  String get reset_settings_to_default => _t('admin.reset_settings_to_default');
  String get reset_settings_to_recent_saved => _t('admin.reset_settings_to_recent_saved');
  String get scanning_library => _t('admin.scanning_library');
  String get search_jobs => _t('admin.search_jobs');
  String get send_welcome_email => _t('admin.send_welcome_email');
  String get server_external_domain_settings => _t('admin.server_external_domain_settings');
  String get server_external_domain_settings_description => _t('admin.server_external_domain_settings_description');
  String get server_public_users => _t('admin.server_public_users');
  String get server_public_users_description => _t('admin.server_public_users_description');
  String get server_settings => _t('admin.server_settings');
  String get server_settings_description => _t('admin.server_settings_description');
  String get server_stats_page_description => _t('admin.server_stats_page_description');
  String get server_welcome_message => _t('admin.server_welcome_message');
  String get server_welcome_message_description => _t('admin.server_welcome_message_description');
  String get settings_page_description => _t('admin.settings_page_description');
  String get sidecar_job => _t('admin.sidecar_job');
  String get sidecar_job_description => _t('admin.sidecar_job_description');
  String get slideshow_duration_description => _t('admin.slideshow_duration_description');
  String get smart_search_job_description => _t('admin.smart_search_job_description');
  String get storage_template_date_time_description => _t('admin.storage_template_date_time_description');
  String storage_template_date_time_sample({required Object date}) =>
      _t('admin.storage_template_date_time_sample', {'date': date});
  String get storage_template_enable_description => _t('admin.storage_template_enable_description');
  String get storage_template_hash_verification_enabled => _t('admin.storage_template_hash_verification_enabled');
  String get storage_template_hash_verification_enabled_description =>
      _t('admin.storage_template_hash_verification_enabled_description');
  String get storage_template_migration => _t('admin.storage_template_migration');
  String storage_template_migration_description({required Object template}) =>
      _t('admin.storage_template_migration_description', {'template': template});
  String storage_template_migration_info({required Object job}) =>
      _t('admin.storage_template_migration_info', {'job': job});
  String get storage_template_migration_job => _t('admin.storage_template_migration_job');
  String get storage_template_more_details => _t('admin.storage_template_more_details');
  String get storage_template_onboarding_description_v2 => _t('admin.storage_template_onboarding_description_v2');
  String storage_template_path_length({required int length, required int limit}) =>
      _t('admin.storage_template_path_length', {'length': length, 'limit': limit});
  String get storage_template_settings => _t('admin.storage_template_settings');
  String get storage_template_settings_description => _t('admin.storage_template_settings_description');
  String storage_template_user_label({required Object label}) =>
      _t('admin.storage_template_user_label', {'label': label});
  String get system_settings => _t('admin.system_settings');
  String get tag_cleanup_job => _t('admin.tag_cleanup_job');
  String template_email_available_tags({required Object tags}) =>
      _t('admin.template_email_available_tags', {'tags': tags});
  String get template_email_if_empty => _t('admin.template_email_if_empty');
  String get template_email_invite_album => _t('admin.template_email_invite_album');
  String get template_email_preview => _t('admin.template_email_preview');
  String get template_email_settings => _t('admin.template_email_settings');
  String get template_email_update_album => _t('admin.template_email_update_album');
  String get template_email_welcome => _t('admin.template_email_welcome');
  String get template_settings => _t('admin.template_settings');
  String get template_settings_description => _t('admin.template_settings_description');
  String get theme_custom_css_settings => _t('admin.theme_custom_css_settings');
  String get theme_custom_css_settings_description => _t('admin.theme_custom_css_settings_description');
  String get theme_settings => _t('admin.theme_settings');
  String get theme_settings_description => _t('admin.theme_settings_description');
  String get thumbnail_generation_job => _t('admin.thumbnail_generation_job');
  String get thumbnail_generation_job_description => _t('admin.thumbnail_generation_job_description');
  String get transcoding_acceleration_api => _t('admin.transcoding_acceleration_api');
  String get transcoding_acceleration_api_description => _t('admin.transcoding_acceleration_api_description');
  String get transcoding_acceleration_nvenc => _t('admin.transcoding_acceleration_nvenc');
  String get transcoding_acceleration_qsv => _t('admin.transcoding_acceleration_qsv');
  String get transcoding_acceleration_rkmpp => _t('admin.transcoding_acceleration_rkmpp');
  String get transcoding_acceleration_vaapi => _t('admin.transcoding_acceleration_vaapi');
  String get transcoding_accepted_audio_codecs => _t('admin.transcoding_accepted_audio_codecs');
  String get transcoding_accepted_audio_codecs_description => _t('admin.transcoding_accepted_audio_codecs_description');
  String get transcoding_accepted_containers => _t('admin.transcoding_accepted_containers');
  String get transcoding_accepted_containers_description => _t('admin.transcoding_accepted_containers_description');
  String get transcoding_accepted_video_codecs => _t('admin.transcoding_accepted_video_codecs');
  String get transcoding_accepted_video_codecs_description => _t('admin.transcoding_accepted_video_codecs_description');
  String get transcoding_advanced_options_description => _t('admin.transcoding_advanced_options_description');
  String get transcoding_audio_codec => _t('admin.transcoding_audio_codec');
  String get transcoding_audio_codec_description => _t('admin.transcoding_audio_codec_description');
  String get transcoding_bitrate_description => _t('admin.transcoding_bitrate_description');
  String get transcoding_codecs_learn_more => _t('admin.transcoding_codecs_learn_more');
  String get transcoding_constant_quality_mode => _t('admin.transcoding_constant_quality_mode');
  String get transcoding_constant_quality_mode_description => _t('admin.transcoding_constant_quality_mode_description');
  String get transcoding_constant_rate_factor => _t('admin.transcoding_constant_rate_factor');
  String get transcoding_constant_rate_factor_description => _t('admin.transcoding_constant_rate_factor_description');
  String get transcoding_disabled_description => _t('admin.transcoding_disabled_description');
  String get transcoding_encoding_options => _t('admin.transcoding_encoding_options');
  String get transcoding_encoding_options_description => _t('admin.transcoding_encoding_options_description');
  String get transcoding_hardware_acceleration => _t('admin.transcoding_hardware_acceleration');
  String get transcoding_hardware_acceleration_description => _t('admin.transcoding_hardware_acceleration_description');
  String get transcoding_hardware_decoding => _t('admin.transcoding_hardware_decoding');
  String get transcoding_hardware_decoding_setting_description =>
      _t('admin.transcoding_hardware_decoding_setting_description');
  String get transcoding_max_b_frames => _t('admin.transcoding_max_b_frames');
  String get transcoding_max_b_frames_description => _t('admin.transcoding_max_b_frames_description');
  String get transcoding_max_bitrate => _t('admin.transcoding_max_bitrate');
  String get transcoding_max_bitrate_description => _t('admin.transcoding_max_bitrate_description');
  String get transcoding_max_keyframe_interval => _t('admin.transcoding_max_keyframe_interval');
  String get transcoding_max_keyframe_interval_description => _t('admin.transcoding_max_keyframe_interval_description');
  String get transcoding_optimal_description => _t('admin.transcoding_optimal_description');
  String get transcoding_policy => _t('admin.transcoding_policy');
  String get transcoding_policy_description => _t('admin.transcoding_policy_description');
  String get transcoding_preferred_hardware_device => _t('admin.transcoding_preferred_hardware_device');
  String get transcoding_preferred_hardware_device_description =>
      _t('admin.transcoding_preferred_hardware_device_description');
  String get transcoding_preset_preset => _t('admin.transcoding_preset_preset');
  String get transcoding_preset_preset_description => _t('admin.transcoding_preset_preset_description');
  String get transcoding_reference_frames => _t('admin.transcoding_reference_frames');
  String get transcoding_reference_frames_description => _t('admin.transcoding_reference_frames_description');
  String get transcoding_required_description => _t('admin.transcoding_required_description');
  String get transcoding_settings => _t('admin.transcoding_settings');
  String get transcoding_settings_description => _t('admin.transcoding_settings_description');
  String get transcoding_target_resolution => _t('admin.transcoding_target_resolution');
  String get transcoding_target_resolution_description => _t('admin.transcoding_target_resolution_description');
  String get transcoding_temporal_aq => _t('admin.transcoding_temporal_aq');
  String get transcoding_temporal_aq_description => _t('admin.transcoding_temporal_aq_description');
  String get transcoding_threads => _t('admin.transcoding_threads');
  String get transcoding_threads_description => _t('admin.transcoding_threads_description');
  String get transcoding_tone_mapping => _t('admin.transcoding_tone_mapping');
  String get transcoding_tone_mapping_description => _t('admin.transcoding_tone_mapping_description');
  String get transcoding_transcode_policy => _t('admin.transcoding_transcode_policy');
  String get transcoding_transcode_policy_description => _t('admin.transcoding_transcode_policy_description');
  String get transcoding_two_pass_encoding => _t('admin.transcoding_two_pass_encoding');
  String get transcoding_two_pass_encoding_setting_description =>
      _t('admin.transcoding_two_pass_encoding_setting_description');
  String get transcoding_video_codec => _t('admin.transcoding_video_codec');
  String get transcoding_video_codec_description => _t('admin.transcoding_video_codec_description');
  String get trash_enabled_description => _t('admin.trash_enabled_description');
  String get trash_number_of_days => _t('admin.trash_number_of_days');
  String get trash_number_of_days_description => _t('admin.trash_number_of_days_description');
  String get trash_settings => _t('admin.trash_settings');
  String get trash_settings_description => _t('admin.trash_settings_description');
  String get unlink_all_oauth_accounts => _t('admin.unlink_all_oauth_accounts');
  String get unlink_all_oauth_accounts_description => _t('admin.unlink_all_oauth_accounts_description');
  String get unlink_all_oauth_accounts_prompt => _t('admin.unlink_all_oauth_accounts_prompt');
  String get user_cleanup_job => _t('admin.user_cleanup_job');
  String user_delete_delay({required int delay, required Object user}) =>
      _t('admin.user_delete_delay', {'delay': delay, 'user': user});
  String get user_delete_delay_settings => _t('admin.user_delete_delay_settings');
  String get user_delete_delay_settings_description => _t('admin.user_delete_delay_settings_description');
  String user_delete_immediately({required Object user}) => _t('admin.user_delete_immediately', {'user': user});
  String get user_delete_immediately_checkbox => _t('admin.user_delete_immediately_checkbox');
  String get user_details => _t('admin.user_details');
  String get user_management => _t('admin.user_management');
  String get user_password_has_been_reset => _t('admin.user_password_has_been_reset');
  String get user_password_reset_description => _t('admin.user_password_reset_description');
  String user_restore_description({required Object user}) => _t('admin.user_restore_description', {'user': user});
  String user_restore_scheduled_removal({required String date}) =>
      _t('admin.user_restore_scheduled_removal', {'date': date});
  String get user_settings => _t('admin.user_settings');
  String get user_settings_description => _t('admin.user_settings_description');
  String user_successfully_removed({required Object email}) => _t('admin.user_successfully_removed', {'email': email});
  String get users_page_description => _t('admin.users_page_description');
  String get version_check_enabled_description => _t('admin.version_check_enabled_description');
  String get version_check_implications => _t('admin.version_check_implications');
  String get version_check_settings => _t('admin.version_check_settings');
  String get version_check_settings_description => _t('admin.version_check_settings_description');
  String get video_conversion_job => _t('admin.video_conversion_job');
  String get video_conversion_job_description => _t('admin.video_conversion_job_description');
}

class _ErrorsTranslations extends _BaseTranslations {
  @override
  final BuildContext? _context;
  _ErrorsTranslations._(this._context);
  String get cannot_navigate_next_asset => _t('errors.cannot_navigate_next_asset');
  String get cannot_navigate_previous_asset => _t('errors.cannot_navigate_previous_asset');
  String get cant_apply_changes => _t('errors.cant_apply_changes');
  String cant_change_activity({required bool enabled}) => _t('errors.cant_change_activity', {'enabled': enabled});
  String get cant_change_asset_favorite => _t('errors.cant_change_asset_favorite');
  String cant_change_metadata_assets_count({required int count}) =>
      _t('errors.cant_change_metadata_assets_count', {'count': count});
  String get cant_get_faces => _t('errors.cant_get_faces');
  String get cant_get_number_of_comments => _t('errors.cant_get_number_of_comments');
  String get cant_search_people => _t('errors.cant_search_people');
  String get cant_search_places => _t('errors.cant_search_places');
  String get error_adding_assets_to_album => _t('errors.error_adding_assets_to_album');
  String get error_adding_users_to_album => _t('errors.error_adding_users_to_album');
  String get error_deleting_shared_user => _t('errors.error_deleting_shared_user');
  String error_downloading({required Object filename}) => _t('errors.error_downloading', {'filename': filename});
  String get error_hiding_buy_button => _t('errors.error_hiding_buy_button');
  String get error_removing_assets_from_album => _t('errors.error_removing_assets_from_album');
  String get error_selecting_all_assets => _t('errors.error_selecting_all_assets');
  String get exclusion_pattern_already_exists => _t('errors.exclusion_pattern_already_exists');
  String get failed_to_create_album => _t('errors.failed_to_create_album');
  String get failed_to_create_shared_link => _t('errors.failed_to_create_shared_link');
  String get failed_to_edit_shared_link => _t('errors.failed_to_edit_shared_link');
  String get failed_to_get_people => _t('errors.failed_to_get_people');
  String get failed_to_keep_this_delete_others => _t('errors.failed_to_keep_this_delete_others');
  String get failed_to_load_asset => _t('errors.failed_to_load_asset');
  String get failed_to_load_assets => _t('errors.failed_to_load_assets');
  String get failed_to_load_notifications => _t('errors.failed_to_load_notifications');
  String get failed_to_load_people => _t('errors.failed_to_load_people');
  String get failed_to_remove_product_key => _t('errors.failed_to_remove_product_key');
  String get failed_to_reset_pin_code => _t('errors.failed_to_reset_pin_code');
  String get failed_to_stack_assets => _t('errors.failed_to_stack_assets');
  String get failed_to_unstack_assets => _t('errors.failed_to_unstack_assets');
  String get failed_to_update_notification_status => _t('errors.failed_to_update_notification_status');
  String get incorrect_email_or_password => _t('errors.incorrect_email_or_password');
  String get library_folder_already_exists => _t('errors.library_folder_already_exists');
  String get page_not_found => _t('errors.page_not_found');
  String paths_validation_failed({required int paths}) => _t('errors.paths_validation_failed', {'paths': paths});
  String get profile_picture_transparent_pixels => _t('errors.profile_picture_transparent_pixels');
  String get quota_higher_than_disk_size => _t('errors.quota_higher_than_disk_size');
  String get something_went_wrong => _t('errors.something_went_wrong');
  String get unable_to_add_album_users => _t('errors.unable_to_add_album_users');
  String get unable_to_add_assets_to_shared_link => _t('errors.unable_to_add_assets_to_shared_link');
  String get unable_to_add_comment => _t('errors.unable_to_add_comment');
  String get unable_to_add_exclusion_pattern => _t('errors.unable_to_add_exclusion_pattern');
  String get unable_to_add_partners => _t('errors.unable_to_add_partners');
  String unable_to_add_remove_archive({required bool archived}) =>
      _t('errors.unable_to_add_remove_archive', {'archived': archived});
  String unable_to_add_remove_favorites({required bool favorite}) =>
      _t('errors.unable_to_add_remove_favorites', {'favorite': favorite});
  String unable_to_archive_unarchive({required bool archived}) =>
      _t('errors.unable_to_archive_unarchive', {'archived': archived});
  String get unable_to_change_album_user_role => _t('errors.unable_to_change_album_user_role');
  String get unable_to_change_date => _t('errors.unable_to_change_date');
  String get unable_to_change_description => _t('errors.unable_to_change_description');
  String get unable_to_change_favorite => _t('errors.unable_to_change_favorite');
  String get unable_to_change_location => _t('errors.unable_to_change_location');
  String get unable_to_change_password => _t('errors.unable_to_change_password');
  String unable_to_change_visibility({required int count}) =>
      _t('errors.unable_to_change_visibility', {'count': count});
  String get unable_to_complete_oauth_login => _t('errors.unable_to_complete_oauth_login');
  String get unable_to_connect => _t('errors.unable_to_connect');
  String get unable_to_copy_to_clipboard => _t('errors.unable_to_copy_to_clipboard');
  String get unable_to_create => _t('errors.unable_to_create');
  String get unable_to_create_admin_account => _t('errors.unable_to_create_admin_account');
  String get unable_to_create_api_key => _t('errors.unable_to_create_api_key');
  String get unable_to_create_library => _t('errors.unable_to_create_library');
  String get unable_to_create_user => _t('errors.unable_to_create_user');
  String get unable_to_delete_album => _t('errors.unable_to_delete_album');
  String get unable_to_delete_asset => _t('errors.unable_to_delete_asset');
  String get unable_to_delete_assets => _t('errors.unable_to_delete_assets');
  String get unable_to_delete_exclusion_pattern => _t('errors.unable_to_delete_exclusion_pattern');
  String get unable_to_delete_shared_link => _t('errors.unable_to_delete_shared_link');
  String get unable_to_delete_user => _t('errors.unable_to_delete_user');
  String get unable_to_delete_workflow => _t('errors.unable_to_delete_workflow');
  String get unable_to_download_files => _t('errors.unable_to_download_files');
  String get unable_to_edit_exclusion_pattern => _t('errors.unable_to_edit_exclusion_pattern');
  String get unable_to_empty_trash => _t('errors.unable_to_empty_trash');
  String get unable_to_enter_fullscreen => _t('errors.unable_to_enter_fullscreen');
  String get unable_to_exit_fullscreen => _t('errors.unable_to_exit_fullscreen');
  String get unable_to_get_comments_number => _t('errors.unable_to_get_comments_number');
  String get unable_to_get_shared_link => _t('errors.unable_to_get_shared_link');
  String get unable_to_hide_person => _t('errors.unable_to_hide_person');
  String get unable_to_link_motion_video => _t('errors.unable_to_link_motion_video');
  String get unable_to_link_oauth_account => _t('errors.unable_to_link_oauth_account');
  String get unable_to_log_out_all_devices => _t('errors.unable_to_log_out_all_devices');
  String get unable_to_log_out_device => _t('errors.unable_to_log_out_device');
  String get unable_to_login_with_oauth => _t('errors.unable_to_login_with_oauth');
  String get unable_to_play_video => _t('errors.unable_to_play_video');
  String unable_to_reassign_assets_existing_person({required String name}) =>
      _t('errors.unable_to_reassign_assets_existing_person', {'name': name});
  String get unable_to_reassign_assets_new_person => _t('errors.unable_to_reassign_assets_new_person');
  String get unable_to_refresh_user => _t('errors.unable_to_refresh_user');
  String get unable_to_remove_album_users => _t('errors.unable_to_remove_album_users');
  String get unable_to_remove_api_key => _t('errors.unable_to_remove_api_key');
  String get unable_to_remove_assets_from_shared_link => _t('errors.unable_to_remove_assets_from_shared_link');
  String get unable_to_remove_library => _t('errors.unable_to_remove_library');
  String get unable_to_remove_partner => _t('errors.unable_to_remove_partner');
  String get unable_to_remove_reaction => _t('errors.unable_to_remove_reaction');
  String get unable_to_reset_password => _t('errors.unable_to_reset_password');
  String get unable_to_reset_pin_code => _t('errors.unable_to_reset_pin_code');
  String get unable_to_resolve_duplicate => _t('errors.unable_to_resolve_duplicate');
  String get unable_to_restore_assets => _t('errors.unable_to_restore_assets');
  String get unable_to_restore_trash => _t('errors.unable_to_restore_trash');
  String get unable_to_restore_user => _t('errors.unable_to_restore_user');
  String get unable_to_save_album => _t('errors.unable_to_save_album');
  String get unable_to_save_api_key => _t('errors.unable_to_save_api_key');
  String get unable_to_save_date_of_birth => _t('errors.unable_to_save_date_of_birth');
  String get unable_to_save_name => _t('errors.unable_to_save_name');
  String get unable_to_save_profile => _t('errors.unable_to_save_profile');
  String get unable_to_save_settings => _t('errors.unable_to_save_settings');
  String get unable_to_scan_libraries => _t('errors.unable_to_scan_libraries');
  String get unable_to_scan_library => _t('errors.unable_to_scan_library');
  String get unable_to_set_feature_photo => _t('errors.unable_to_set_feature_photo');
  String get unable_to_set_profile_picture => _t('errors.unable_to_set_profile_picture');
  String get unable_to_set_rating => _t('errors.unable_to_set_rating');
  String get unable_to_submit_job => _t('errors.unable_to_submit_job');
  String get unable_to_trash_asset => _t('errors.unable_to_trash_asset');
  String get unable_to_unlink_account => _t('errors.unable_to_unlink_account');
  String get unable_to_unlink_motion_video => _t('errors.unable_to_unlink_motion_video');
  String get unable_to_update_album_cover => _t('errors.unable_to_update_album_cover');
  String get unable_to_update_album_info => _t('errors.unable_to_update_album_info');
  String get unable_to_update_library => _t('errors.unable_to_update_library');
  String get unable_to_update_location => _t('errors.unable_to_update_location');
  String get unable_to_update_settings => _t('errors.unable_to_update_settings');
  String get unable_to_update_timeline_display_status => _t('errors.unable_to_update_timeline_display_status');
  String get unable_to_update_user => _t('errors.unable_to_update_user');
  String get unable_to_update_workflow => _t('errors.unable_to_update_workflow');
  String get unable_to_upload_file => _t('errors.unable_to_upload_file');
}

class _IntervalTranslations extends _BaseTranslations {
  @override
  final BuildContext? _context;
  _IntervalTranslations._(this._context);
  String get day_at_onepm => _t('interval.day_at_onepm');
  String hours({required int hours}) => _t('interval.hours', {'hours': hours});
  String get night_at_midnight => _t('interval.night_at_midnight');
  String get night_at_twoam => _t('interval.night_at_twoam');
}

class _PastDurationsTranslations extends _BaseTranslations {
  @override
  final BuildContext? _context;
  _PastDurationsTranslations._(this._context);
  String days({required int days}) => _t('past_durations.days', {'days': days});
  String hours({required int hours}) => _t('past_durations.hours', {'hours': hours});
  String years({required int years}) => _t('past_durations.years', {'years': years});
}
