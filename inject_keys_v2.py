import sys

file_path = r"e:\aloo_sbji_mandi\lib\core\utils\app_localizations.dart"

chunk = """
    // Admin Screens Localization
    'failed_to_load_admins': 'Failed to load admins',
    'create_new_admin': 'Create New Admin',
    'first_name': 'First Name',
    'last_name': 'Last Name',
    'phone_number': 'Phone Number',
    'email_optional': 'Email (Optional)',
    'password': 'Password',
    'cancel': 'Cancel',
    'fill_all_required_fields': 'Please fill all required fields',
    'password_min_6_chars': 'Password must be at least 6 characters',
    'admin_created_success': 'Admin created successfully',
    'failed_to_create_admin': 'Failed to create admin',
    'create_admin_button': 'Create Admin',
    'edit_admin': 'Edit Admin',
    'new_password_optional': 'New Password (leave empty to keep)',
    'admin_updated_success': 'Admin updated successfully',
    'failed_to_update_admin': 'Failed to update admin',
    'update': 'Update',
    'delete_admin': 'Delete Admin',
    'are_you_sure_delete_admin': 'Are you sure you want to permanently delete ',
    'this_action_cannot_be_undone': '?\\n\\nThis action cannot be undone.',
    'delete': 'Delete',
    'admin_deleted_success': 'Admin deleted successfully',
    'failed_to_delete_admin': 'Failed to delete admin',
    'demote_admin': 'Demote Admin',
    'demote_prefix': 'Demote ',
    'demote_suffix': ' to:',
    'role_farmer': 'Farmer',
    'role_trader': 'Trader',
    'role_cold_storage': 'Cold Storage',
    'role_aloo_mitra': 'Aloo Mitra',
    'demote': 'Demote',
    'admin_demoted_success': 'Admin demoted successfully',
    'failed_to_demote_admin': 'Failed to demote admin',
    'manage_admins': 'Manage Admins',
    'manage_admins_title': 'Manage Admins',
    'create_edit_remove_admins': 'Create, edit, or remove admin accounts',
    'add_admin_action': 'Add Admin',
    'no_admins_found': 'No admins found',
    'tap_plus_create_admin': 'Tap + to create a new admin',
    'master_badge': 'MASTER',
    'admin_badge': 'ADMIN',
    'edit': 'Edit',
    'protected_admin_msg': 'Protected — Cannot be modified or deleted',
    
    'failed_to_pick_image': 'Failed to pick image: ',
    'image_upload_failed': 'Image upload failed: ',
    'please_enter_a_title': 'Please enter a title',
    'please_enter_a_message': 'Please enter a message',
    'title_less_than_200': 'Title must be less than 200 characters',
    'message_less_than_1000': 'Message must be less than 1000 characters',
    'failed_to_upload_image': 'Failed to upload image. Try again.',
    'confirm_broadcast': 'Confirm Broadcast',
    'send_notification_to_all_msg': 'This will send a notification to ALL users in the app.',
    'title_label': 'Title: ',
    'message_label': 'Message: ',
    'with_image_yes': 'With Image: Yes',
    'send_to_all': 'Send to All',
    'notification_sent_successfully': 'Notification sent successfully!',
    'authentication_required': 'Authentication Required',
    'session_expired_login_again': 'Your session may have expired. Please login again as admin.',
    'ok': 'OK',
    'failed_to_send_notification': 'Failed to send notification',
    'error_label': 'Error',
    'send_broadcast_notification_title': 'Send Broadcast Notification',
    'sending_notification_to_all': 'Sending notification to all users...',
    'broadcast_notification_info': 'This notification will be sent to all users (Farmers, Traders, Cold Storage, Aloo Mitra)',
    'notification_title_required': 'Notification Title *',
    'eg_important_update': 'e.g., Important Update',
    'notification_message_required': 'Notification Message *',
    'eg_important_announcement': 'e.g., Dear users, we have an important announcement...',
    'notification_image_optional': 'Notification Image (Optional)',
    'change_image': 'Change Image',
    'remove': 'Remove',
    'uploading_image': 'Uploading image...',
    'add_image': 'Add Image',
    'send_to_all_users': 'Send to All Users',
    
    'all_tab': 'All',
    'pending_tab': 'Pending',
    'approved_tab': 'Approved',
    'active_tab': 'Active',
    'advertisement_approved': 'Advertisement approved!',
    'failed_to_approve': 'Failed to approve',
    'advertisement_rejected': 'Advertisement rejected',
    'failed_to_reject': 'Failed to reject',
    'confirm_payment_message': 'Are you sure the payment has been received? This will activate the advertisement.',
    'confirm_pay_btn': 'Confirm Pay',
    'payment_confirmed_active': 'Payment confirmed! Ad is now active.',
    'failed_to_confirm': 'Failed to confirm',
    'confirm_delete_ad_msg1': 'Are you sure you want to permanently delete ',
    'confirm_delete_ad_msg2': '?\\n\\nThis action cannot be undone.',
    'advertisement_deleted': 'Advertisement deleted!',
    'failed_to_delete': 'Failed to delete',
    'edit_ad_image': 'Edit Ad Image',
    'new_image_tap_change': 'New image • Tap to change',
    'tap_to_replace': 'Tap to replace',
    'tap_add_image': 'Tap to add image',
    'title_required_error': 'Title is required',
    'advertisement_updated_success': 'Advertisement updated!',
    'failed_to_update_msg': 'Failed to update',
    'save_changes': 'Save Changes',
    'edit_banner_image': 'Edit Banner Image',
    'tap_to_change_banner': 'Tap to change',
    'tap_upload_banner_image': 'Tap to upload banner image *',
    'jpg_png_gallery': 'JPG, PNG • Gallery',
    'banner_title_required_error': 'Banner title is required',
    'please_upload_banner_image': 'Please upload a banner image',
    'banner_created_activated': 'Banner created and activated!',
    'failed_to_create_banner': 'Failed to create banner',
    'create_activate': 'Create & Activate',
    'no_advertisements_found': 'No advertisements found',
    'untitled': 'Untitled',
    'slide_prefix': 'Slide ',
    'approve': 'Approve',
    'days': 'days',
"""

with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
in_map = False
maps_modified = 0

for line in lines:
    if line.startswith("  static const Map<String, String> _") and line.strip().endswith(" = {"):
        # We are entering a language map definition
        # But ignore _languageNames and _localeSubtitles if they don't share the same signature precisely
        if not ("_languageNames" in line or "_localeSubtitles" in line):
            in_map = True
    elif in_map and line.strip() == "};":
        # Found the end of the map. Inject before this line.
        new_lines.append(chunk + "\n")
        in_map = False
        maps_modified += 1
    
    new_lines.append(line)

print(f"Maps modified: {maps_modified}")

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("Finished.")
