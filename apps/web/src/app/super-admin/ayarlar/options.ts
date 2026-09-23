// Trial lengths offered in the Super Admin form. The database accepts
// 0-90 days (subscription_settings check constraint), so adding a value
// here is all that's needed to offer another option.
export const APP_TRIAL_DAY_OPTIONS: readonly number[] = [0, 3, 7];
