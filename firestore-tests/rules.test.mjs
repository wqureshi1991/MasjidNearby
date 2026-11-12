// Security rules tests for ../firestore.rules. Run with `npm test` in this folder, which starts
// the Firestore emulator under the offline "demo-" project, so nothing touches real data.
import { after, beforeEach, describe, test } from "node:test";
import { readFileSync } from "node:fs";
import { assertFails, assertSucceeds, initializeTestEnvironment } from "@firebase/rules-unit-testing";
import {
  collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where,
} from "firebase/firestore";

const testEnv = await initializeTestEnvironment({
  projectId: "demo-masjidnearby",
  firestore: { rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8") },
});

// --- Helpers ----------------------------------------------------------------------------------

const db = (uid) => testEnv.authenticatedContext(uid).firestore();
const guestDB = () => testEnv.authenticatedContext("guest", { firebase: { sign_in_provider: "anonymous" } }).firestore();
const publicDB = () => testEnv.unauthenticatedContext().firestore();

/** Writes fixtures with the rules switched off. */
const seed = (write) => testEnv.withSecurityRulesDisabled((context) => write(context.firestore()));

const masjidData = (adminUID, overrides = {}) => ({
  name: "Masjid Al-Noor",
  address: "1 Main St, San Jose, CA",
  latitude: 37.3382,
  longitude: -121.8863,
  geohash: "9q9k",
  timeZone: "America/Los_Angeles",
  adminUIDs: [adminUID],
  verified: false,
  createdAt: serverTimestamp(),
  ...overrides,
});

const dayData = (day, overrides = {}) => ({
  day,
  source: "manual",
  sunrise: "07:04",
  fajr: { adhan: "05:53", iqamah: "06:15" },
  dhuhr: { adhan: "12:57" },
  asr: { adhan: "16:17" },
  maghrib: { adhan: "18:49" },
  isha: { adhan: "20:01" },
  ...overrides,
});

/** An admin account, plus a masjid it administers. */
async function seedMasjid({ id = "m1", admin = "admin1", verified = false } = {}) {
  await seed(async (firestore) => {
    await setDoc(doc(firestore, `users/${admin}`), { role: "masjidAdmin", createdAt: new Date() });
    await setDoc(doc(firestore, `masjids/${id}`), { ...masjidData(admin), verified, createdAt: new Date() });
  });
}

beforeEach(() => testEnv.clearFirestore());
after(() => testEnv.cleanup());

// --- users/{uid} ------------------------------------------------------------------------------

describe("user profiles", () => {
  test("an account creates its own profile with a valid role", async () => {
    await assertSucceeds(setDoc(doc(db("alice"), "users/alice"), { role: "user", createdAt: serverTimestamp() }));
  });

  test("an account can't create someone else's profile", async () => {
    await assertFails(setDoc(doc(db("alice"), "users/bob"), { role: "user", createdAt: serverTimestamp() }));
  });

  test("guests have no profile", async () => {
    await assertFails(setDoc(doc(guestDB(), "users/guest"), { role: "user", createdAt: serverTimestamp() }));
  });

  test("only the known roles and fields are allowed", async () => {
    await assertFails(setDoc(doc(db("alice"), "users/alice"), { role: "superAdmin", createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(db("alice"), "users/alice"), {
      role: "user", createdAt: serverTimestamp(), verified: true,
    }));
  });

  test("the role can't change after sign-up", async () => {
    await seed((firestore) => setDoc(doc(firestore, "users/alice"), { role: "user", createdAt: new Date() }));
    await assertFails(updateDoc(doc(db("alice"), "users/alice"), { role: "masjidAdmin" }));
  });

  test("profiles are private", async () => {
    await seed((firestore) => setDoc(doc(firestore, "users/alice"), { role: "user", createdAt: new Date() }));
    await assertSucceeds(getDoc(doc(db("alice"), "users/alice")));
    await assertFails(getDoc(doc(db("bob"), "users/alice")));
    await assertFails(getDoc(doc(publicDB(), "users/alice")));
  });
});

// --- masjids/{id} -----------------------------------------------------------------------------

describe("masjids", () => {
  test("a masjid admin registers an unverified masjid as its only admin", async () => {
    await seed((firestore) => setDoc(doc(firestore, "users/admin1"), { role: "masjidAdmin", createdAt: new Date() }));
    await assertSucceeds(setDoc(doc(db("admin1"), "masjids/new"), masjidData("admin1")));
  });

  test("worshipper accounts can't register masjids", async () => {
    await seed((firestore) => setDoc(doc(firestore, "users/alice"), { role: "user", createdAt: new Date() }));
    await assertFails(setDoc(doc(db("alice"), "masjids/new"), masjidData("alice")));
  });

  test("a new masjid can't be verified or have other admins", async () => {
    await seed((firestore) => setDoc(doc(firestore, "users/admin1"), { role: "masjidAdmin", createdAt: new Date() }));
    await assertFails(setDoc(doc(db("admin1"), "masjids/a"), masjidData("admin1", { verified: true })));
    await assertFails(setDoc(doc(db("admin1"), "masjids/b"), masjidData("admin1", { adminUIDs: ["admin1", "bob"] })));
  });

  test("anyone can read a verified masjid", async () => {
    await seedMasjid({ verified: true });
    await assertSucceeds(getDoc(doc(publicDB(), "masjids/m1")));
    await assertSucceeds(getDoc(doc(guestDB(), "masjids/m1")));
  });

  test("an unverified masjid is visible only to its admin", async () => {
    await seedMasjid({ verified: false });
    await assertFails(getDoc(doc(publicDB(), "masjids/m1")));
    await assertFails(getDoc(doc(db("bob"), "masjids/m1")));
    await assertSucceeds(getDoc(doc(db("admin1"), "masjids/m1")));
  });

  test("the nearby search query is allowed, an unfiltered list isn't", async () => {
    await seedMasjid({ verified: true });
    const masjids = collection(publicDB(), "masjids");
    await assertSucceeds(getDocs(query(masjids,
      where("verified", "==", true), where("geohash", ">=", "9q9"), where("geohash", "<=", "9q9~"))));
    await assertFails(getDocs(masjids));
  });

  test("its admin edits the details but can't verify it or change admins", async () => {
    await seedMasjid();
    const masjid = doc(db("admin1"), "masjids/m1");
    await assertSucceeds(updateDoc(masjid, { name: "Masjid An-Noor", updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(masjid, { verified: true }));
    await assertFails(updateDoc(masjid, { adminUIDs: ["admin1", "bob"] }));
  });

  test("nobody else can edit, and nobody can delete", async () => {
    await seedMasjid({ verified: true });
    await assertFails(updateDoc(doc(db("bob"), "masjids/m1"), { name: "Taken" }));
    await assertFails(deleteDoc(doc(db("admin1"), "masjids/m1")));
  });
});

// --- masjids/{id}/schedule/{day} --------------------------------------------------------------

describe("schedules", () => {
  test("its admin publishes a valid day", async () => {
    await seedMasjid();
    await assertSucceeds(setDoc(doc(db("admin1"), "masjids/m1/schedule/2026-11-12"), dayData("2026-11-12")));
    await assertSucceeds(setDoc(doc(db("admin1"), "masjids/m1/schedule/2026-11-13"),
      dayData("2026-11-13", { source: "ocr" })));
  });

  test("malformed days are rejected", async () => {
    await seedMasjid();
    const day = doc(db("admin1"), "masjids/m1/schedule/2026-11-12");
    await assertFails(setDoc(day, dayData("2026-11-12", { sunrise: "24:00" })));
    await assertFails(setDoc(day, dayData("2026-11-12", { isha: { adhan: "8:01 PM" } })));
    await assertFails(setDoc(day, dayData("2026-11-12", { source: "calculated" })));
    await assertFails(setDoc(day, dayData("2026-11-13")));
  });

  test("other accounts can't publish", async () => {
    await seedMasjid({ verified: true });
    await assertFails(setDoc(doc(db("bob"), "masjids/m1/schedule/2026-11-12"), dayData("2026-11-12")));
  });

  test("a verified masjid's schedule is public; an unverified one's isn't", async () => {
    await seedMasjid({ id: "open", verified: true });
    await seedMasjid({ id: "pending", verified: false });
    await seed(async (firestore) => {
      await setDoc(doc(firestore, "masjids/open/schedule/2026-11-12"), dayData("2026-11-12"));
      await setDoc(doc(firestore, "masjids/pending/schedule/2026-11-12"), dayData("2026-11-12"));
    });
    await assertSucceeds(getDoc(doc(publicDB(), "masjids/open/schedule/2026-11-12")));
    await assertFails(getDoc(doc(publicDB(), "masjids/pending/schedule/2026-11-12")));
    await assertSucceeds(getDoc(doc(db("admin1"), "masjids/pending/schedule/2026-11-12")));
  });
});

// --- Everything else --------------------------------------------------------------------------

describe("other paths", () => {
  test("are closed", async () => {
    await assertFails(setDoc(doc(db("alice"), "events/e1"), { title: "Halaqa" }));
    await assertFails(getDoc(doc(publicDB(), "events/e1")));
  });
});
