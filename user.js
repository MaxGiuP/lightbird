/*
  Lightbird
  https://github.com/reizumii/lightbird
*/

/* --- enable userchrome theming --- */
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
/*user_pref("svg.context-properties.content.enabled", true);*/
/* Thunderbird built-in dark reader — gconversations uses this to apply
   dark mode inside message iframes via its injectCss() mechanism. */
user_pref("mail.dark-reader.enabled", true);
