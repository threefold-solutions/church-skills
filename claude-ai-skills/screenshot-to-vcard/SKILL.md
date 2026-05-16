---
name: screenshot-to-vcard
description: Convert any screenshot containing contact information into a downloadable vCard (.vcf) file. Trigger this skill whenever a user uploads any screenshot — from Planning Center, a CRM, a website, a LinkedIn profile, an email signature, a business card photo, or any other source — and wants to convert it into a contact, vCard, or shareable address book card. Trigger on phrases like "turn this into a contact", "make a vCard", "convert this screenshot", "grab their contact info", "I want to share this person's info", "generate a contact card", or any time a screenshot is uploaded and contact info is mentioned. Works with any app or source — not just Planning Center. Extracts name, email, phone, and address, confirms with the user which fields to include, then generates a ready-to-send .vcf file.
---

# Screenshot to vCard

Converts any screenshot containing contact information into a downloadable vCard (.vcf) file — ready to text, email, or AirDrop.

Works with screenshots from any source: Planning Center, Church Management Systems, CRMs, LinkedIn, websites, email signatures, business card photos, and more.

---

## Step 1: Extract Contact Data from the Screenshot

Visually scan the screenshot and extract every contact field that is clearly visible. Look for:

| Field | Common appearances |
|-------|-------------------|
| Full Name | Header text, bold name, profile name |
| Email(s) | Any @domain.com address, labeled or unlabeled |
| Phone(s) | Any phone number, labeled mobile/cell/home/work or unlabeled |
| Address(es) | Street address, city, state, zip — may be single or multi-line |
| Organization / Title | Company name, job title, church role |
| Website | Any URL associated with the person |

**Rules:**
- Do NOT guess or infer fields that aren't visible
- Do NOT make up or autocomplete partial data
- If a field label is visible (home, work, mobile, etc.), capture it
- If multiple values exist for a field type, capture all of them

---

## Step 2: Present Extracted Data and Ask Which Fields to Include

After extracting, show a clean summary:

```
Here's what I found:

- Name: [Full Name]
- Email: [email] ([label if present])
- Phone: [number] ([label if present])
- Address: [full address]

Which fields would you like in the vCard?
```

Then use `ask_user_input_v0` with a `multi_select` question. List each found field as its own option so the user can pick exactly what to include. Wait for their selection before proceeding.

---

## Step 3: Generate the vCard File

Build a `.vcf` file using vCard 3.0 format based on selected fields only.

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
- Email label "home" → `TYPE=HOME`, "work" → `TYPE=WORK`, unlabeled → `TYPE=INTERNET`
- Phone label "mobile" or "cell" → `TYPE=CELL`, "home" → `TYPE=HOME`, "work" → `TYPE=WORK`, unlabeled → `TYPE=VOICE`
- Address label "home" → `TYPE=HOME`, "work" → `TYPE=WORK`, unlabeled → `TYPE=HOME`
- Multiple emails or phones → one line per entry
- If no country visible, default to `United States`
- Only include lines for fields the user selected

**Name parsing:**
- "First Last" → `N:Last;First;;;`
- Middle name present → `N:Last;First;Middle;;`
- Single name only → `N:[Name];;;;`

### Save the File

Save to `/mnt/user-data/outputs/[firstname_lastname].vcf`

Use lowercase with underscores. If name has more than two parts, use first and last only in the filename.

---

## Step 4: Present and Briefly Explain Sharing Options

After generating, use `present_files` to surface the file, then add one short line about sharing — text/email the file, AirDrop if nearby, or tap to import into their own contacts. Keep it brief.

---

## Edge Cases

- **No name visible**: Use whatever identifier is present (username, email prefix, etc.) as FN; skip the N field
- **Name only**: Still generate — a minimal vCard is still useful
- **Partial address**: Include what's visible; leave missing ADR subfields blank
- **Business card photo**: Treat the same as any screenshot — extract what's readable
- **Low-res or blurry**: Extract what can be confidently read; flag any uncertain fields before confirming with the user
- **Non-Latin characters**: Preserve them as-is in the vCard
- **Multiple people in one screenshot**: Ask which person they want the vCard for before extracting
