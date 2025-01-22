+++
title = "Basic Org file"
author = ["Óscar Nájera"]
draft = false
weight = 1003
+++

The basic structure of an org file containing your CV is shown next.


## Personal contact information {#personal-contact-information}

`TITLE`, `AUTHOR` and `EMAIL` are standard org options. But on `TITLE` you
put your foreseen job.

<div class="ox-hugo-table table table-striped">

| Field    | Description                                        |
|----------|----------------------------------------------------|
| TITLE    | Desired job                                        |
| AUTHOR   | Who are you?                                       |
| EMAIL    | Your contact email                                 |
| ADDRESS  | Mailing address, this can span over multiple lines |
| HOMEPAGE | URL of your website                                |
| MOBILE   | Mobile phone                                       |
| GITHUB   | GitHub user                                        |
| GITLAB   | GitLab user                                        |
| LINKEDIN | Linkedin username                                  |
| PHOTO    | path to photo file                                 |

</div>

```org
#+TITLE: My dream job an ORG-CV example
#+AUTHOR: John Doe
#+email: john@doe.lost
#+options: tags:nil

#+ADDRESS: My Awesome crib
#+ADDRESS: Fantastic city -- Planet Earth
#+MOBILE: (+9) 87654321
#+HOMEPAGE: example.com
#+GITHUB: Titan-C
#+GITLAB: Titan-C
#+LINKEDIN: oscar-najera
#+PHOTO: smile.png
```

You can use org-modes hierarchical structure to describe your CV. To make a
specific sub-tree an item describing an experience point (Job you have, degree
you pursued, etc.) you use the org properties drawer and with the `:CV_ENV:
cventry` property. You should also include the `FROM` and `TO` properties
defining the span of the entry, as well as `LOCATION` and `EMPLOYER`.

Because work isn't everything we do, it is more meaningful to label differently
the host of those other events like studies, events, certifications, etc.  Thus
`HOST`, `ORGANIZATION`, `INSTITUTION`, `SCHOOL`, `EMPLOYER` or `EVENT`  are all
equivalent and the first match in that order has precedence.

`DATE` is a shortcut for `FROM` and `TO` when you have a single date in mind
instead of a range. Both `FROM` and `TO` override `DATE`.

```org
* Employement  :cventries:
** One job  :cventry:
:PROPERTIES:
:CV_ENV: cventry
:FROM:     <2014-09-01>
:TO:     <2017-12-07>
:LOCATION: a city, a country
:EMPLOYER: The employer
:NOTE: Extra note: everybody here loved me
:END:

I write about awesome stuff I do.
** Other job  :cventry:
:PROPERTIES:
:FROM:     <2013-09-01>
:TO:     <2014-08-07>
:LOCATION: my city, your country
:EMPLOYER: The other employer
:END:

I write about awesome stuff I do.

* Other stuff I do
- I work a lot
- I sleep a lot
- I eat a lot
```
