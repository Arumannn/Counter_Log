# Logbook App - Praktikum Penerapan Prinsip SRP

## 📖 Tentang Proyek

Aplikasi Counter sederhana yang dibangun menggunakan Flutter dengan menerapkan **Single Responsibility Principle (SRP)** sebagai salah satu prinsip SOLID dalam pengembangan perangkat lunak.

---

## 🎯 Apa itu Single Responsibility Principle (SRP)?

**Single Responsibility Principle (SRP)** adalah prinsip pertama dari SOLID yang menyatakan bahwa:

> *"Sebuah class seharusnya hanya memiliki satu alasan untuk berubah."*
> — Robert C. Martin

Dengan kata lain, setiap class atau modul harus memiliki **satu tanggung jawab tunggal** dan fokus pada satu aspek fungsionalitas saja.

### Manfaat Penerapan SRP:
- ✅ **Mudah dipelihara** - Perubahan pada satu fitur tidak mempengaruhi fitur lain
- ✅ **Mudah diuji** - Setiap class dapat diuji secara independen
- ✅ **Mudah dipahami** - Kode lebih terstruktur dan readable
- ✅ **Reusable** - Komponen dapat digunakan kembali di tempat lain
- ✅ **Mengurangi bug** - Perubahan terlokalisasi, mengurangi efek samping

---

## 🏗️ Struktur Proyek

```
lib/
├── main.dart              # Entry point aplikasi
├── counter_controller.dart # Logic bisnis (Controller)
└── counter_view.dart       # Tampilan UI (View)
```

---

## 🔍 Penerapan SRP pada Praktikum

### 1. `main.dart` - Entry Point & Konfigurasi Aplikasi

**Tanggung Jawab:** Menginisialisasi dan mengkonfigurasi aplikasi Flutter.

**Penjelasan SRP:**
- Class `MyApp` hanya bertanggung jawab untuk konfigurasi tema dan routing awal
- Tidak mengandung logic bisnis atau tampilan kompleks
- Jika ada perubahan tema atau konfigurasi, hanya file ini yang perlu diubah

---

### 2. `counter_controller.dart` - Business Logic Layer

**Tanggung Jawab:** Mengelola state dan logic bisnis counter.

**Penjelasan SRP:**
- Class `CounterController` **hanya** menangani:
  - Penyimpanan nilai counter
  - Operasi increment, decrement, reset
  - Pencatatan history
- **Tidak mengetahui** bagaimana data ditampilkan (UI)
- **Tidak bergantung** pada Flutter widgets
- Mudah diuji secara unit test tanpa UI

---

### 3. `counter_view.dart` - Presentation Layer

**Tanggung Jawab:** Menampilkan UI dan menangani interaksi pengguna.

**Penjelasan SRP:**
- Class `CounterView` **hanya** menangani:
  - Rendering tampilan (Scaffold, Text, Buttons)
  - Menangkap input pengguna
  - Memanggil controller untuk operasi bisnis
- **Tidak mengetahui** bagaimana perhitungan dilakukan
- **Tidak menyimpan** logic bisnis

---

## 📊 Diagram Pemisahan Tanggung Jawab

```
┌─────────────────────────────────────────────────────────┐
│                        main.dart                         │
│              (Konfigurasi & Entry Point)                 │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    counter_view.dart                     │
│                    (Presentation Layer)                  │
│  - Menampilkan UI                                        │
│  - Menangani input user                                  │
│  - Memanggil controller                                  │
└─────────────────────────┬───────────────────────────────┘
                          │ uses
                          ▼
┌─────────────────────────────────────────────────────────┐
│                 counter_controller.dart                  │
│                   (Business Logic Layer)                 │
│  - Menyimpan state counter                               │
│  - Operasi: increment, decrement, reset                  │
│  - Mengelola history                                     │
└─────────────────────────────────────────────────────────┘
```

---

## ⚖️ Perbandingan: Dengan SRP vs Tanpa SRP

### ❌ Tanpa SRP (Anti-Pattern)

Ketika semua logic bisnis dan UI digabungkan dalam satu class:
- Sulit di-maintain karena satu perubahan bisa berdampak ke banyak bagian
- Sulit di-test karena UI dan logic tercampur
- Perubahan UI bisa mempengaruhi logic bisnis
- Kode tidak reusable

### ✅ Dengan SRP (Best Practice)

Ketika Controller dan View dipisahkan:
- Mudah di-maintain karena setiap class fokus pada satu tugas
- Controller bisa di-test tanpa perlu menjalankan UI
- Perubahan UI tidak mempengaruhi logic bisnis
- Controller bisa digunakan kembali di tempat lain

---

## 📝 Kesimpulan

Pada praktikum ini, prinsip **Single Responsibility Principle (SRP)** diterapkan dengan memisahkan aplikasi menjadi tiga komponen utama:

| File | Tanggung Jawab | Alasan Berubah |
|------|----------------|----------------|
| `main.dart` | Konfigurasi aplikasi | Perubahan tema/routing |
| `counter_controller.dart` | Logic bisnis counter | Perubahan cara perhitungan |
| `counter_view.dart` | Tampilan UI | Perubahan desain tampilan |

Dengan pemisahan ini, setiap komponen memiliki **satu alasan untuk berubah**, sehingga kode lebih **mudah dipelihara, diuji, dan dikembangkan**.

---
