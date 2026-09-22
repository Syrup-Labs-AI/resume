# Resume (syrp.ai/resume)

Alan Karp's live resume: `index.html` is the site, hand-maintained; `resume.json` and
`resume.txt` are kept roughly in sync as data sources; `llms.txt` is the profile written for
AI agents. Written 2026-09-21 after a measurement found this repository carried no
CLAUDE.md while being the surface every recruiter in Alan's inbox is sent to. Rules only.

## 1. Never run `render.js`

`README-DO-NOT-RUN-RENDER.md` says why and it is still true: `index.html` diverged from the
jsonresume theme long ago and carries custom CSS, JSON-LD, OpenGraph tags and hand-tuned
sections that `render.js` would destroy. Edit `index.html` directly. If a session ever
needs the generator, it says so first and waits for Alan's letter.

## 2. Three files carry the same claims; a change lands in all three or in none

`index.html`, `resume.json` and `resume.txt`. The commit history shows what happens
otherwise: "truth pass part 2: resume.txt was missed", "truth pass part 3: resume.json, the
last file carrying the claims". A claim removed from one and left in another is a resume
that lies in one format. `grep -c "<the claim>" index.html resume.json resume.txt` before
and after every edit; the three counts must move together.

## 3. Every claim is VERIFIED or it is not on the page

The job-search pipeline in the vault keeps a facts file where each claim is marked VERIFIED
or UNVERIFIED with the evidence behind it; on 2026-08-27 it quarantined a resume carrying
false claims. Nothing goes onto this site that the facts file cannot back. A session that
cannot reach the vault (any container, the VM) does not add a claim; it opens a question for
the PC.

## 4. Contact details

The phone number on the site was wrong once (commit `b53452f`: "tel href and resume.json
phone dialed the retired 443 number"). The email and the phone are read from `index.html`,
never typed from memory, and never repeated into a chat transcript; a session that needs
to check them runs `grep -o 'tel:[^"]*' index.html` and reports whether the three files agree.

## 5. Style

Rule 0 of the estate applies to prose here: no em dashes, no `--`. Measured 2026-09-21:
`index.html` carries 10 em dashes, `resume.txt` and `resume.json` carry 0. Those ten are
Alan's to rule on, because a resume's typography is a choice; they are recorded so nobody
adds an eleventh by accident. Commit `aee2cbe` already removed two literal double hyphens.

## 6. The estate rules

`CLAUDE.md` in the `xxOS` repository holds the rules for every repository: which machine
you are on, never report what you did not run, never type a count a command can produce,
multiple-choice questions at every decision point, nothing deleted or archived. They apply
here. `SyrupLabsAI` is a personal GitHub account and `Syrup-Labs-AI` is the organisation;
this repository's remote may name either and the redirect proves nothing about access.

## 7. Conventions

Conventional Commits. No AI attribution trailers. Never push to `main` directly: the site
is what recruiters open, and a broken push is a broken interview.
