# Attributions

Works the app uses that are not packages. Packages and their licences are
listed by the app itself (Settings > Licences, from Flutter's licence
registry). The same entries are in `attributions` in `app/lib/legal.dart`,
shown under Settings > Licences > Other attributions.

## Fonts

Bundled in `app/assets/fonts/`, each with its licence file next to it:

- Roboto, by Google, Apache License 2.0.
- Noto Sans Devanagari, Telugu, Tamil, Malayalam and Gurmukhi, by the Noto
  Project Authors, SIL Open Font License 1.1.

## Illustrative Mathematics (test data only)

`app/test/algebra_known_answers_test.dart` holds known-answer rows: an
equation and the answer printed for it on a page of

- IM 6–8 Math, originally developed by Open Up Resources and authored by
  Illustrative Mathematics, copyright 2017-2019 Open Up Resources;
  adaptations and updates copyright 2019 Illustrative Mathematics; and
- IM K–5 Math, copyright 2021 Illustrative Mathematics,

as published at https://im.kendallhunt.com, licensed under the Creative
Commons Attribution 4.0 International License (CC BY 4.0,
https://creativecommons.org/licenses/by/4.0/). Each row names the page it
was read from.

The rows are used only to test that the app's questions and answers agree
with the textbook; they are not shipped in the app. Changes were made: the
equations are rewritten in the app's notation (the letter n or a box for the
unknown, and the signs −, × and ÷). The Illustrative Mathematics name and
logo are not covered by the licence, and neither Illustrative Mathematics
nor Open Up Resources endorses this app.
