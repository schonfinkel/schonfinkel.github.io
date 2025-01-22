+++
title = "Markdown Hugo Exporter"
author = ["Óscar Nájera"]
draft = false
weight = 1005
+++

If your target is not a PDF file but a website, this exporter extends the
[ox-hugo](https://ox-hugo.scripter.co/) exporter backend. So be sure to install that too.

To export, there is nothing fancy to keep track of, but as an example I
exclude some tags during export.

```emacs-lisp
(let ((org-export-exclude-tags '("noexport" "latexonly")))
     (org-export-to-file 'hugocv "hugocv.md"))
```

You are responsible for styling your website. Use all the CSS magic you know.
Each entry is inside a `div` container and each element of the properties has
its own class.

Make sure that your hugo config has the markup parser attributes active and allows
for html rendering.

```yaml
markup:
  goldmark:
    renderer:
      unsafe: true
    parser:
      attribute:
        title: true
        block: true
```

You can also use an awards section for a different styling.  Here you tag each
entry with `cvhonor`.

```org
* Awards
** First place  :cvhonor:
:PROPERTIES:
:CV_ENV: cventry
:DATE:     <2014-09-01>
:LOCATION: a city, a country
:EVENT: The RACE
:END:

** Sport Scholarship  :cvhonor:
:PROPERTIES:
:DATE:     <2013-09-01>
:LOCATION: my city, your country
:ORGANIZATION: The nice millionaire
:END:
```

Next is the rendered result for the special entries with styling.
