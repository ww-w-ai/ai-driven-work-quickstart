# Google Workspace MCP Setup Guide (Internal Mode - Admin)

> This guide explains how an admin at a company using Google Workspace can set things up.

---

## This Guide Is For You If

- [x] Your company uses Google Workspace (e.g., @yourcompany.com email)
- [x] You are the company's IT admin or have Google Cloud Console access
- [x] You want to set things up so company employees can use the tool

---

## Internal Mode Advantages

| Item | Internal Mode |
|------|---------------|
| Number of users | **Unlimited** |
| Token expiration | **None** (can be used indefinitely) |
| Google review | Not required |
| Warning screen | None |

---

## Automatic Setup (Recommended)

The installer's Google module will automatically guide you through the setup.

**Windows:** Press `Win + R` and run
```powershell
powershell -ep bypass -c "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.ps1))) -modules 'google'"
```

**Mac/Linux:** Run in Terminal
```bash
curl -fsSL https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.sh | MODULES="google" bash
```

After running, select "Admin" → Follow the on-screen instructions to complete setup.

> The manual setup below is only needed if the automatic installer does not work or you need it for reference.

---

## Manual Setup (Reference)

### Step 1: Google Cloud Console Setup

### 1-1. Create a Project

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click the project selector at the top → **New Project**
3. Project name: `Google Workspace MCP`
4. Click **Create**

### 1-2. Enable APIs

1. Left menu **APIs & Services** → **Enable APIs and Services**
2. Search for and click **Enable** for each of the following 6 APIs:

| API | Search Term |
|-----|-------------|
| Gmail API | gmail |
| Google Calendar API | calendar |
| Google Drive API | drive |
| Google Docs API | docs |
| Google Sheets API | sheets |
| Google Slides API | slides |

### 1-3. Configure OAuth Consent Screen (Important!)

1. Left menu **OAuth consent screen**
2. Click **Audience** in the left menu
3. Click **Get Started**

#### Enter App Information

| Item | Value |
|------|-------|
| App name | `Google Workspace MCP` |
| User support email | Your email |
| **Audience** | **Internal** — Required! |
| Contact information | Your email |

Click **Save**

### 1-4. Data Access (Scopes) Configuration

1. Left menu **Data Access**
2. Click **Add Scope**
3. Select the following 7 scopes:

| API | Scope (Search) |
|-----|-----------------|
| Gmail API | `gmail.modify` |
| Gmail API | `gmail.send` |
| Calendar API | `calendar` |
| Drive API | `drive` |
| Docs API | `documents` |
| Sheets API | `spreadsheets` |
| Slides API | `presentations` |

4. Click **Save**

### 1-5. Create OAuth Client ID

1. Left menu **Clients**
2. Click **+ Create OAuth Client**
3. Configuration:

| Item | Value |
|------|-------|
| Application type | **Desktop app** |
| Name | `MCP Client` |

4. Click **Create**
5. Click the **Download JSON** icon
6. Rename the file to `client_secret.json`

---

## Step 2: Prepare for Employee Deployment

### Files to distribute to employees

You only need to distribute the `client_secret.json` file.

### Sample message for employees

```
Hello, here are the Google MCP setup instructions.

1. Save the attached client_secret.json file

2. Run the installation command below:

   Windows: Press Win+R and run the following command
   powershell -ep bypass -c "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.ps1))) -modules 'google'"

   Mac: Run the following command in Terminal
   curl -fsSL https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/install.sh | MODULES="google" bash

3. Select "Employee" in the Google MCP setup
4. Copy the client_secret.json file to the specified location
5. Log in with your Google account

Contact: IT Team
```

---

## Security Notes

**Do not share externally:**
- `client_secret.json` - Share only within the company
- Never distribute to anyone outside the company

---

## Next Steps

- Share the "Sample message for employees" above with your employees
- You can also install other modules together:
  - Atlassian: `-modules 'google,atlassian'` (Docker required)
  - Notion: `-modules 'google,notion'`
  - GitHub: `-modules 'google,github'`
  - Figma: `-modules 'google,figma'`
  - All modules: `-all`
