/*
  Lightbird
  https://github.com/reizumii/lightbird
*/

/* enable userChrome.css / userContent.css theming */
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

/* enable SVG context-properties so theme icons receive fill colours */
user_pref("svg.context-properties.content.enabled", true);

/* built-in dark reader — used by Thunderbird Conversations inside message iframes */
user_pref("mail.dark-reader.enabled", true);

/* show compact header band in Thunderbird Conversations (1 = minimal) */
user_pref("mail.show_headers", 1);
