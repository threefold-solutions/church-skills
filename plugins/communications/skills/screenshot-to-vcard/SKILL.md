---
name: screenshot-to-vcard
description: Convert any screenshot containing contact information into a downloadable vCard (.vcf) file. Trigger whenever the user shares a screenshot — from Planning Center, a CRM, a website, a LinkedIn profile, an email signature, a business card photo, or any other source — and wants to turn it into a contact, vCard, or shareable address-book card. Trigger on phrases like "turn this into a contact", "make a vCard", "convert this screenshot", "grab their contact info", "I want to share this person's info", "generate a contact card", or any time a screenshot is shared and contact info is mentioned. Works with any app or source — not just Planning Center.
allowed-tools: AskUserQuestion, Read, Write, Bash
---

# Screenshot to vCard

Convert any screenshot containing contact information into a downloadable vCard (`.vcf`) file — ready to text, email, or AirDrop.

Works with screenshots from any source: Planning Center, Church Management Systems, CRMs, LinkedIn, websites, email signatures, business card photos, and more.

---

## Step 1: Extract Contact Data from the Screenshot

Visually scan the screenshot the user shared and extract every contact field that is clearly visible. Look for:

| Field | Common appearances |
|-------|-------------------|
| Full Name | Header text, bold name, profile name |
| Email(s) | Any `@domain.com` address, labeled or unlabeled |
| Phone(s) | Any phone number, labeled mobile/cell/home/work or unlabeled |
| Address(es) | Street address, city, state, zip — may be single or multi-line |
| Organization / Title | Company name, job title, church role |
| Website | Any URL associated with the person |

**Rules:**
- Do NOT guess or infer fields that aren't visible.
- Do NOT make up or autocomplete partial data.
- If a field label is visible (home, work, mobile, etc.), capture it.
- If multiple values exist for a field type, capture all of them.

---

## Step 2: Confirm Which Fields to Include

Show a clean summary of what you found, then let the user pick exactly which fields to include in the vCard, listing each found field as its own option.

Use the surface's native multi-select structured-input capability if it has one. If it does not, ask the question in plain text and wait for the answer before continuing — never assume the selection.

Example summary before asking:

```
Here's what I found:

- Name: Jane Doe
- Email: jane@example.com (work)
- Phone: 555-123-4567 (mobile)
- Address: 123 Main St, Springfield, IL 62701
```

Wait for the user's selection before proceeding. If the user shared a screenshot containing **multiple people**, ask which person first.

---

## Step 3: Generate the vCard File

Build a `.vcf` file using vCard 3.0 format based on the selected fields only.

### vCard 3.0 Template

```
BEGIN:VCARD
VERSION:3.0
FN:[Full Name]
N:[Last];[First];;;
EMAIL;TYPE=[HOME|WORK]:[email]
TEL;TYPE=[CELL|HOME|WORK]:[phone]
ADR;TYPE=[HOME|WORK]:;;[Street];[City];[State];[Zip];[Country]
ORG:[Organization]
TITLE:[Job Title]
URL:[Website]
END:VCARD
```

**Field mapping:**
- Email label `home` → `TYPE=HOME`; `work` → `TYPE=WORK`; unlabeled → `TYPE=INTERNET`
- Phone label `mobile` or `cell` → `TYPE=CELL`; `home` → `TYPE=HOME`; `work` → `TYPE=WORK`; unlabeled → `TYPE=VOICE`
- Address label `home` → `TYPE=HOME`; `work` → `TYPE=WORK`; unlabeled → `TYPE=HOME`
- Multiple emails or phones → one line per entry.
- If no country is visible, default to `United States`.
- Only include lines for fields the user selected.

**Name parsing:**
- `First Last` → `N:Last;First;;;`
- Middle name present → `N:Last;First;Middle;;`
- Single name only → `N:[Name];;;;`

### Save the File

Save to the user's Downloads folder using the surface's native file-writing capability:

```
~/Downloads/[firstname_lastname].vcf
```

Use lowercase with underscores. If the name has more than two parts, use first and last only in the filename. If the user is on a system without `~/Downloads/`, fall back to the current working directory.

---

## Step 4: Tell the User Where It Is and How to Use It

After writing the file, tell the user:

1. The absolute path of the saved `.vcf` file.
2. One short line on sharing options — text/email the file, AirDrop if nearby, or open it to import into their own contacts.

Keep it brief — no long explanations.

---

## Edge Cases

- **No name visible**: Use whatever identifier is present (username, email prefix, etc.) as `FN`; skip the `N` field.
- **Name only**: Still generate — a minimal vCard is still useful.
- **Partial address**: Include what's visible; leave missing `ADR` subfields blank.
- **Business card photo**: Treat the same as any screenshot — extract what's readable.
- **Low-res or blurry**: Extract what can be confidently read; flag any uncertain fields before confirming with the user.
- **Non-Latin characters**: Preserve them as-is in the vCard.
- **Multiple people in one screenshot**: Ask which person they want the vCard for before extracting.
