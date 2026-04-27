# 🏛️ Government MDT (v2.5) - Professional Public Service System

A comprehensive and modern Government Management Data Terminal (MDT) built for FiveM. This system allows government officials to manage announcements, process citizen applications, and issue physical legal documents directly to player inventories.

![Gov MDT Preview](https://img.shields.io/badge/Status-Stable-success?style=for-the-badge)
![Framework](https://img.shields.io/badge/Framework-Qbox/QBCore-blue?style=for-the-badge)
![UI](https://img.shields.io/badge/UI-Vanilla_CSS_&_JS-orange?style=for-the-badge)

## ✨ Core Features

- **📊 Dynamic Dashboard**: Real-time stats on citizen population, government revenue, and warehouse health.
- **📢 Official Announcements**: Post laws, regulations, and public news for all government staff.
- **📋 Public Service Registration**:
  - Citizens can register for **Kartu Keluarga (KK)**, **Surat Izin Usaha (SIU)**, and **Sertifikat Tanah (ST)** at dedicated NPC points.
  - Integrated with a large, professional "Official Document" UI for clear data entry.
- **📑 Legal Document Management**:
  - Staff can view, edit, and certify citizen applications.
  - **Physical Handover**: Issue official documents as inventory items (Ox Inventory) with custom metadata and digital signatures.
- **📦 Warehouse Integration**: Built-in stash management for government supplies with large capacity (200 slots).
- **🎨 Premium Aesthetics**: Modern, dark-themed UI with smooth animations and responsive design.

## 📦 Installation

### 1. Requirements

- `qbx_core` (or compatible QBCore)
- `ox_lib`
- `ox_inventory`
- `ox_target`
- `oxmysql`

### 2. Database Setup

Ensure you have the following tables in your database:

```sql
CREATE TABLE IF NOT EXISTS `gov_documents` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `title` VARCHAR(100) NOT NULL,
    `content` TEXT NOT NULL,
    `author` VARCHAR(100) NOT NULL,
    `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `gov_announcements` ... -- (Automatically created on first run)
```

### 3. Inventory Configuration

Add the following to your `ox_inventory/data/items.lua`:

```lua
['legal_document'] = {
    label = 'Legal Document',
    weight = 10,
    stack = false,
    close = true,
    description = 'An official government document.',
    server = {
        export = 'gov-mdt.legal_document'
    }
}
```

_Note: Place the provided `legal_document.png` into `ox_inventory/web/images/`._

## 🚀 How to Use

### For Citizens

1.  Go to the **Public Service Point** (Balaikota area).
2.  Talk to the Clerk and select **"Register Official Documents"**.
3.  Fill in the large official form with your details (use the provided templates for KK/SIU/ST).

### For Government Staff

1.  Open the MDT and navigate to **Legal Documents**.
2.  Find the citizen's application (Author: _Citizen Self-Service_).
3.  Click **Edit** (Pencil icon) to finalize the details and add family members or official notes.
4.  Click **Give Copy** (Icon next to Edit) to hand over a physical version to the citizen standing nearby.
5.  The document will automatically show **"Certified By: [Your Name]"**.

## 🛠️ Credits

Developed with ❤️ by **novendra05**.
