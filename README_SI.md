# Mathra Pipes – Premium ඉඟි + Admin ඇප් (v1.3.0)

මේ zip එකේ ඇත්තේ:

| Folder | මොකක්ද |
|---|---|
| `Pipes-main/` | ගේම් එක (Premium plans, අලුත් ඉඟි නීති, analytics එකතු කරලා) |
| `mathra_admin/` | **ඔයාගේ Admin ඇප් එක** (stats, orders, subscribers, prices) |
| `firestore.rules` | Firebase rules (ආරක්ෂාව – **අනිවාර්යයෙන් දාන්න**) |

---

## 1. ඉඟි නීති (ගේම් එකේ)

1. **මුලින්ම නොමිලේ ඉඟි 3** (එක ෆෝන් එකකට එක පාරයි).
2. **ලකුණු 400 ක් ගැහුවාම තවත් 3** – **එක පාරයි** (ආයේ ආයේ දෙන්නේ නැහැ).
3. **Leaderboard එකේ #1 වෙන කෙනාට 3** (online leaderboard එකේ).
   - දෙවැනියා #1 වුණාම එයාට 3 යනවා.
   - කලින් #1 හිටපු කෙනා #2 වුණාම එයාට මුකුත් නැහැ.
   - එක ෆෝන් එකකට මේක **එක පාරයි** (දෙන්නෙක් මාරුවෙන් මාරුවට #1 වෙලා ඉඟි හොයන එක නවත්තන්න).
     අනිත් විදියට කරන්න ඕන නම් `hint_config.dart` එකේ `rankOneOncePerDevice = false`.
4. ඒ ඔක්කොම ඉවර වුණාම → **Premium plan** (පහල).

මේ අගයන් ඔක්කොම `Pipes-main/lib/data/services/hint_config.dart` එකේ වෙනස් කරන්න පුළුවන්.

## 2. Premium plans (ගේම් එකේත්, Admin ඇප් එකේත්)

| Plan | දවස් | මිල |
|---|---|---|
| දවස් 1 | 1 | Rs 5 |
| දවස් 2 | 2 | Rs 10 |
| මාස 1 | 30 | Rs 100 |
| මාස 2 | 60 | Rs 200 |
| මාස 6 | 180 | Rs 500 |
| අවුරුද්ද 1 | 365 | Rs 1000 |

- ගේම් එකේ: Home → **Premium ඉඟි** (Settings එකෙත් තියෙනවා; ඉඟි ඉවර වුණාම එන dialog එකෙනුත් යන්න පුළුවන්).
- **මිල / plans වෙනස් කරන්න** → Admin ඇප් එක → **Prices** tab → Save. ගේම් එකට ඉබේම යනවා (අලුතින් ගේම් එක build කරන්න ඕනේ නැහැ). Plan එකක් අලුතින් එකතු කරන්නත්, නැති කරන්නත් පුළුවන්.

### ගෙවීම ක්‍රියා කරන හැටි (ඇත්තටම "original" – ඇප් එක හරහා විතරයි activate වෙන්නේ)
1. Player plan එකක් තෝරනවා → **Order** එකක් Firebase එකට යනවා (code එකක් එක්ක, status = pending).
2. Player ගෙවලා (bank / eZ Cash) **WhatsApp එකෙන් slip + order code** එක ඔයාට යවනවා (බොත්තමක් තියෙනවා).
3. ඔයා **Admin ඇප් → Orders → Pending → "Confirm paid"** ඔබනවා (සල්ලි ඇත්තටම ආවාම විතරක්).
4. එතකොට Firebase එකේ `subs/<DeviceID>` ලියවෙනවා. ගේම් එක තත්පර 12 කට වරක් බලනවා (plans screen එක open නම්) – **plan එක ඉබේම ON** වෙනවා.
5. **Auto expire**: plan එක ඉවර වෙන වෙලාවට ඉබේම නවතිනවා (දවස් 1 plan = confirm කරපු වෙලාවේ ඉඳන් පැය 24).
   දැනටමත් plan එකක් තියෙද්දී ආයේ ගත්තොත් **කලින් plan එක ඉවර වෙනකොට ඉඳන්** එකතු වෙනවා.
6. **ඇප් එකෙන් අයින් කරන්න**: Admin ඇප් → Subscribers → ⋮ → **Remove plan**. ගේම් එක විනාඩි 5-10 ක් ඇතුළත (ඉඟියක් ඔබනකොට / ඇප් එක open කරනකොට) නවත්තනවා.
7. Device ID එකට manual plan දෙන්නත් පුළුවන් (Subscribers → **Give plan**) – WhatsApp එකෙන් කතා කරපු අයට.

### "Fake" වෙන්නේ නැත්තේ ඇයි
- `subs` (plan ඒවා) Firebase **rules** වලින් **ඔයාගේ admin login එකට විතරයි** ලියන්න දෙන්නේ. ගේම් එකට / modded APK එකකට ලියන්න බැහැ – කියවන්න විතරයි.
- Order එකක මිල ෆෝන් එකෙන් එනවා, ඒත් **Confirm කරනකොට පාවිච්චි කරන්නේ ඔයාගේ Prices list එකේ මිල** (වෙනස් නම් ⚠ අනතුරු ඇඟවීමක් පේනවා).
- ෆෝන් clock එක පස්සට දැම්මත් plan එක දිගු වෙන්නේ නැහැ (ගේම් එක clock එක පස්සට යන්න දෙන්නේ නැහැ + server වෙලාව පාවිච්චි කරනවා).
- ඉතිරි සීමාව (හොඳට දැනගන්න): ඉඟි **නොමිලේ** කොටස් (3 / 400 / #1) ගේම් එකේ ෆෝන් එකේම සේව් වෙන එකක්, ඒ නිසා app data clear කරලා ආයේ ගන්න පුළුවන්. ගෙවන plan එක විතරයි server එකෙන් ආරක්ෂිත. Root කරපු ෆෝන් එකක offline ඉඳන් local file එක edit කරන එක 100% නවත්තන්න බැහැ; ඒත් online වුණු ගමන් server එකේ සත්‍යය එන නිසා plan එක නැති වෙනවා, ඒ වගේම පැය 72 ක් server check නැතුව plan එක වැඩ කරන්නේ නැහැ.

## 3. Admin ඇප් එකේ පේන දේවල්

**Stats tab**: Installs (ගේම් එක open කළ ෆෝන් ගණන) • Viewed plans (plans screen බැලූ ගණන) • Took a plan / orders • Paid customers • Waiting payment • Paid orders • Active subscribers • Expired/removed • Active last 24h / 7 days • Leaderboard players • Rejected • **ආදායම (අද / මේ මාසේ / මුළු)** • Funnel (Install → Viewed → Ordered → Paid).

> සටහන: "Installs" කියන්නේ ගේම් එක ඇත්තටම open කරපු ෆෝන් ගණන (ගේම් එකෙන්ම එන නියම දත්ත). Play Store / APK download ගණන නෙවෙයි. එයාලා ගේම් එක open කරලා නැත්නම් ගණන් වෙන්නේ නැහැ.

**Orders** (Pending / Paid / Rejected) • **Subscribers** (Active / Expired) • **Prices**.

---

## 4. Setup (එක පාරක් කරන්න)

### A. Firebase (ඔයාගේ දැනට තියෙන `mathra-pipes-game` project එකේම)
1. https://console.firebase.google.com → project එක → **Build → Authentication → Get started → Sign-in method → Email/Password → Enable**.
2. **Users → Add user** → ඔයාගේ admin email + **ශක්තිමත් password** එකක්. (මේක ඔයාට විතරයි.)
3. (අමතර ආරක්ෂාවට) Authentication → **Settings → User actions → "Enable create (sign-up)" අයින් කරන්න**.
4. **Build → Firestore Database → Rules** → `firestore.rules` එකේ ඔක්කොම paste කරන්න.
   **පළමු කොටසේ `YOUR_ADMIN_EMAIL@gmail.com` ඔයාගේ admin email එකට මාරු කරන්න.** → **Publish**.
   ⚠ මේක නොකර ගියොත් plans ක්‍රියා කරන්නේ නැහැ (ගේම් එකට order යවන්න බැරි වෙනවා).

### B. Game build
`Pipes-main/` එක පරණ විදියටම build කරන්න (`flutter pub get`, `flutter build apk --release`, නැත්නම් GitHub Actions → Build APK).
`firebase_config.dart` එකේ projectId / apiKey දැනටමත් තියෙනවා (වෙනස් project එකක් නම් මාරු කරන්න).

### C. Admin ඇප් build
`mathra_admin/` එක (ඔයාගේ GitHub repo එකක් අලුතින් හදලා දාන්න, නැත්නම් පරණ එකේ වෙනම folder එකක්) → **Actions → Build APK (simple) → Run**.
නැත්නම් ෆෝන් / PC එකේ: `cd mathra_admin && flutter pub get && flutter build apk --release`.
`lib/firebase_config.dart` එකේ projectId / apiKey **ගේම් එකේ එකටම** තියෙන්න ඕනේ (දැනටමත් දාලා තියෙනවා).
ඇප් එක open කරලා ඔයාගේ admin email + password එකෙන් login වෙන්න.

### D. පළමු test එක
1. Admin ඇප් → **Prices** → ඕනේ නම් Pay info (bank / eZ Cash) සහ WhatsApp number එක ලියලා **Save**.
2. ගේම් එක → Home → **Premium ඉඟි** → **Rs 5** plan එක → Buy → order යනවා.
3. Admin ඇප් → **Orders → Pending** → order එක පේනවා → **Confirm paid**.
4. ගේම් එකේ plans screen එක තත්පර 12 ක් ඇතුළත ✅ පෙන්නනවා; ඉඟි බොත්තම **∞**.
5. Admin → **Subscribers** → ⋮ → **Remove plan** → ගේම් එකේ ඉඟි නවතිනවා.

---

## 5. පරණ Lifetime (WhatsApp code) ගැන
කලින් Rs 100 lifetime code එකෙන් ගත්තු අයගේ code එක (ඒ ෆෝන් එකේ සේව් වෙලා තියෙන) තවමත් වැඩ කරනවා – `licenseSecret` එක වෙනස් කරන්න එපා. අලුත් අයට code ඇතුළත් කරන තැනක් නැහැ; plans විතරයි.
