# i18n Checklist: Korean to English

Files containing Korean text that need to be translated or converted to English.

## P0: Scripts (Korean Comments)

| # | File | Lines | Content |
|---|------|-------|---------|
| 1 | `installer/install.ps1` | 60 | `# 원격 실행 시 $MyInvocation.MyCommand.Path가 null이므로 체크 필요` |
| 2 | `installer/modules/base/install.ps1` | 31 | `# 현재 세션에 즉시 적용` |
| 3 | `installer/modules/base/install.ps1` | 34 | `# 레지스트리에 영구 저장` |
| 4 | `installer/modules/atlassian/install.sh` | 62 | `# Docker 있음: 1=Docker, 2=Rovo` |
| 5 | `installer/modules/atlassian/install.sh` | 67 | `# Docker 없음: 1=Rovo, 2=Docker` |
| 6 | `.github/workflows/test-installer.yml` | 54 | `# CI에서 Clear-Host 실패 방지` |
| 7 | `.github/workflows/test-installer.yml` | 56 | `# Claude native install PATH 추가` |

## P1: User-Facing Documentation

### README & Architecture

| # | File | Action |
|---|------|--------|
| 8 | `README.md` | Rewrite in English (or bilingual) |
| 9 | `installer/ARCHITECTURE.md` | Rewrite in English |
| 10 | `google-workspace-mcp/README.md` | Rewrite in English |

### Setup Guides

| # | File | Action |
|---|------|--------|
| 11 | `google-workspace-mcp/SETUP.md` | Rewrite in English |
| 12 | `google-workspace-mcp/docs/SETUP_COMPANY.md` | Rewrite in English |
| 13 | `google-workspace-mcp/docs/SETUP_EMPLOYEE.md` | Rewrite in English |
| 14 | `google-workspace-mcp/docs/SETUP_PERSONAL.md` | Rewrite in English |
| 15 | `docs/SETUP_GOOGLE_INTERNAL_ADMIN.md` | Rewrite in English |
| 16 | `docs/SETUP_GOOGLE_EXTERNAL_ADMIN.md` | Rewrite in English |

## P2: Landing Page (Separate Repo)

| # | Repo | Action |
|---|------|--------|
| 17 | `ww-w-ai/ai-driven-work-landing` | Add i18n (KO/EN language switcher) |

## P3: Internal PDCA Documents

### 01-plan

| # | File |
|---|------|
| 18 | `docs/01-plan/features/adw-improvement.plan.md` |
| 19 | `docs/01-plan/features/comprehensive-test-plan.md` |
| 20 | `docs/01-plan/features/gemini-cli-support.plan.md` |

### 02-design

| # | File |
|---|------|
| 21 | `docs/02-design/features/adw-improvement.design.md` |
| 22 | `docs/02-design/features/comprehensive-test-design.md` |
| 23 | `docs/02-design/features/gemini-cli-support.design.md` |
| 24 | `docs/02-design/features/sprint-5-code-snippets.md` |
| 25 | `docs/02-design/features/sprint-5-implementation-roadmap.md` |
| 26 | `docs/02-design/features/sprint-5-ux-improvements.design.md` |
| 27 | `docs/02-design/features/sprint-5-ux-improvements-summary.md` |
| 28 | `docs/02-design/security-spec.md` |

### 03-analysis

| # | File |
|---|------|
| 29 | `docs/03-analysis/adw-comprehensive.analysis.md` |
| 30 | `docs/03-analysis/adw-improvement.analysis.md` |
| 31 | `docs/03-analysis/adw-improvement-p1.analysis.md` |
| 32 | `docs/03-analysis/adw-requirements-traceability-matrix.md` |
| 33 | `docs/03-analysis/base-install-error-cases-mac.md` |
| 34 | `docs/03-analysis/base-install-error-cases-windows.md` |
| 35 | `docs/03-analysis/comprehensive-test-report.md` |
| 36 | `docs/03-analysis/gap-check-phase-1.md` |
| 37 | `docs/03-analysis/gap-check-phase-2.md` |
| 38 | `docs/03-analysis/gap-requirements-traceability.md` |
| 39 | `docs/03-analysis/gap-security-verification.md` |
| 40 | `docs/03-analysis/gap-shared-utilities.md` |
| 41 | `docs/03-analysis/shared-utilities-design.md` |
| 42 | `docs/03-analysis/test-strategy.md` |

### 04-report

| # | File |
|---|------|
| 43 | `docs/04-report/features/adw-improvement.report.md` |
| 44 | `docs/04-report/changelog.md` |

### 05-testing

| # | File |
|---|------|
| 45 | `docs/05-testing/manual-test-checklist.md` |

### google-workspace-mcp docs

| # | File |
|---|------|
| 46 | `google-workspace-mcp/docs/01-plan/features/oauth-login.md` |
| 47 | `google-workspace-mcp/CHANGELOG.md` |

## Summary

| Priority | Category | Count | Action |
|----------|----------|-------|--------|
| P0 | Script comments | 7 lines (5 files) | Translate comments to English |
| P1 | User-facing docs | 9 files | Rewrite in English |
| P2 | Landing page | 1 repo | Add i18n support |
| P3 | Internal PDCA docs | 28 files | Translate to English |
| - | .json, .ts files | 0 | No Korean found |
| **Total** | | **43 files + 1 repo** | |
