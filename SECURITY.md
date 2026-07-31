# Security Policy

## Supported versions

Every package here is pre-1.0. Only the latest published version of each package
receives fixes; there are no maintained release branches.

| Package | Supported |
| --- | --- |
| Latest release on pub.dev | ✅ |
| Anything older | ❌ |

## Reporting a vulnerability

Please **do not** open a public issue for a security problem.

Report it through GitHub's private vulnerability reporting on
https://github.com/normidar/colaxy-pkgs/security/advisories/new. Include the
affected package and version, what an attacker can do, and steps to reproduce.

You can expect an initial response within about a week. If a report is accepted,
a fix ships in the next release of the affected package and the advisory is
published once it is available.

## Scope

These are developer libraries and command-line tools; they do not run a service.
Reports that are in scope include things like the CLIs writing outside the
project directory from attacker-controlled config, or a package leaking data it
persists on device. Vulnerabilities in third-party dependencies should be
reported upstream — open a normal issue here so the constraint can be bumped.
