const { readFileSync } = require('node:fs');
const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc,
  writeBatch, serverTimestamp, Timestamp, runTransaction, onSnapshot } = require('firebase/firestore');

let env;
const code = 'a'.repeat(32);
const db = (uid, verified = true) => env.authenticatedContext(uid, { email_verified: verified, email: `${uid}@example.test` }).firestore();
const membership = (fid, invitationId = null) => ({ familyId: fid, invitationId, joinedAt: serverTimestamp() });
const family = (uid, status) => ({ name: 'Testfamilie', ownerId: uid,
  ...(status == null ? {} : { status }), timeZone: 'Europe/Berlin', createdAt: serverTimestamp() });
const memberProfile = (uid, role = 'member', joinedAt = serverTimestamp(), displayName = null) => ({
  email: `${uid}@example.test`, role, joinedAt,
  ...(displayName == null ? {} : { displayName }),
});
async function create(uid, fid, status, displayName = null) {
  const client = db(uid), batch = writeBatch(client);
  batch.set(doc(client, 'families', fid), family(uid, status));
  batch.set(doc(client, 'memberships', uid), membership(fid));
  batch.set(doc(client, 'families', fid, 'members', uid),
    memberProfile(uid, 'owner', serverTimestamp(), displayName));
  await batch.commit();
}
const invitation = (fid = 'alpha') => ({ familyId: fid, createdAt: serverTimestamp(),
  expiresAt: Timestamp.fromMillis(Date.now() + 6 * 86400000), acceptedBy: null, acceptedAt: null });
async function invite() { await setDoc(doc(db('alice'), 'invitations', code), invitation()); }
async function join(uid, invitationCode = code, fid = 'alpha', displayName = null) {
  const client = db(uid), batch = writeBatch(client);
  batch.set(doc(client, 'memberships', uid), membership(fid, invitationCode));
  batch.update(doc(client, 'invitations', invitationCode), { acceptedBy: uid, acceptedAt: serverTimestamp() });
  batch.set(doc(client, 'families', fid, 'members', uid),
    memberProfile(uid, 'member', serverTimestamp(), displayName));
  await batch.commit();
}
async function transfer(client, fid, oldOwner, newOwner, familyChanges = {}) {
  const batch = writeBatch(client);
  batch.update(doc(client, 'families', fid), { ownerId: newOwner, ...familyChanges });
  batch.update(doc(client, 'families', fid, 'members', oldOwner), { role: 'member' });
  batch.update(doc(client, 'families', fid, 'members', newOwner), { role: 'owner' });
  return batch.commit();
}
async function dissolve(client, uid = 'alice', fid = 'alpha') {
  const batch = writeBatch(client);
  batch.update(doc(client, 'families', fid), { status: 'dissolved' });
  batch.delete(doc(client, 'memberships', uid));
  return batch.commit();
}
const event = (uid = 'alice') => ({ title: 'Ausflug', notes: '', year: 2026, month: 8, day: 29,
  startMinute: 540, endMinute: 600, importance: 'normal', reminderMinutesBefore: null,
  revision: 1, updatedBy: uid, updatedAt: serverTimestamp() });
const activity = (action, uid = 'alice', title = 'Ausflug') => ({
  action, eventId: 'a'.repeat(32), title, actorId: uid, createdAt: serverTimestamp(),
});

before(async () => {
  // Hard-coded demo ID: these tests must never target the user's real project.
  env = await initializeTestEnvironment({ projectId: 'demo-moonkeep',
    firestore: { host: '127.0.0.1', port: 8180, rules: readFileSync('firestore.rules', 'utf8') } });
});
beforeEach(async () => { await env.clearFirestore(); await create('alice', 'alpha'); });
after(async () => { if (env) await env.cleanup(); });

test('family creation is atomic and limited to one family per user', async () => {
  await assertSucceeds(getDoc(doc(db('alice'), 'families/alpha')));
  await assertSucceeds(create('charlie', 'active-family', 'active', 'Charlie'));
  assert.equal((await getDoc(doc(db('charlie'),
    'families/active-family/members/charlie'))).data().displayName, 'Charlie');
  await assertFails(create('alice', 'second'));
  await assertFails(setDoc(doc(db('bob'), 'families/orphan'), family('bob')));
  await assertFails(setDoc(doc(db('bob'), 'memberships/bob'), membership('alpha')));
});

test('unverified and anonymous clients cannot access family data', async () => {
  const guest = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(guest, 'families/alpha')));
  await assertFails(getDoc(doc(db('alice', false), 'families/alpha')));
  await assertFails(getDoc(doc(guest, 'memberships/alice')));
});

test('membership is private, immutable, and cannot be forged', async () => {
  await assertFails(updateDoc(doc(db('alice'), 'memberships/alice'), { familyId: 'other' }));
  await assertFails(deleteDoc(doc(db('alice'), 'memberships/alice')));
  await assertFails(setDoc(doc(db('alice'), 'memberships/bob'), membership('alpha')));
  await assertFails(getDocs(collection(db('alice'), 'memberships')));
  await assertFails(getDoc(doc(db('bob'), 'memberships/alice')));
});

test('owner can inspect only memberships belonging to the owned family', async () => {
  await invite();
  await join('bob');
  await create('eve', 'other');
  await assertSucceeds(getDoc(doc(db('alice'), 'memberships/bob')));
  await assertFails(getDoc(doc(db('alice'), 'memberships/eve')));
});

test('only the owner manages invitations and strangers cannot enumerate', async () => {
  await assertFails(getDoc(doc(db('alice'), 'invitations', code)));
  await invite();
  await assertSucceeds(getDocs(query(collection(db('alice'), 'invitations'), where('familyId', '==', 'alpha'))));
  await assertSucceeds(getDoc(doc(db('bob'), 'invitations', code)));
  await assertFails(getDocs(collection(db('bob'), 'invitations')));
  await join('bob');
  await assertFails(setDoc(doc(db('bob'), 'invitations', 'b'.repeat(32)), invitation()));
  await assertFails(deleteDoc(doc(db('bob'), 'invitations', code)));
  await assertFails(setDoc(doc(db('alice'), 'invitations/1234'), invitation()));
  await assertFails(setDoc(doc(db('alice'), 'invitations', 'b'.repeat(32)), {
    ...invitation(), expiresAt: Timestamp.fromMillis(Date.now() + 8 * 86400000),
  }));
  await assertSucceeds(deleteDoc(doc(db('alice'), 'invitations', code)));
});

test('join consumes a code atomically and grants only its family', async () => {
  await invite();
  await assertFails(setDoc(doc(db('bob'), 'memberships/bob'), membership('alpha', code)));
  await assertFails(updateDoc(doc(db('bob'), 'invitations', code), {
    acceptedBy: 'bob', acceptedAt: serverTimestamp(),
  }));
  await assertSucceeds(join('bob', code, 'alpha', 'Bob'));
  assert.equal((await getDoc(doc(db('bob'),
    'families/alpha/members/bob'))).data().displayName, 'Bob');
  await assertSucceeds(getDoc(doc(db('bob'), 'families/alpha')));
  await assertFails(join('eve'));
  await create('charlie', 'beta');
  await assertFails(getDoc(doc(db('bob'), 'families/beta')));
});

test('family members can read only their own roster', async () => {
  await invite();
  await join('bob');
  await create('eve', 'other');
  await assertSucceeds(getDocs(collection(db('bob'), 'families/alpha/members')));
  await assertSucceeds(getDoc(doc(db('alice'), 'families/alpha/members/bob')));
  await assertFails(getDocs(collection(db('eve'), 'families/alpha/members')));
  await assertFails(getDoc(doc(db('alice', false), 'families/alpha/members/alice')));
});

test('member profiles cannot be forged, changed, or removed', async () => {
  const client = db('alice');
  await assertFails(setDoc(doc(client, 'families/alpha/members/bob'), memberProfile('bob')));
  await assertFails(updateDoc(doc(client, 'families/alpha/members/alice'), { role: 'member' }));
  await assertFails(deleteDoc(doc(client, 'families/alpha/members/alice')));
  await invite();
  const bob = db('bob'), batch = writeBatch(bob);
  batch.set(doc(bob, 'memberships/bob'), membership('alpha', code));
  batch.update(doc(bob, 'invitations', code), { acceptedBy: 'bob', acceptedAt: serverTimestamp() });
  batch.set(doc(bob, 'families/alpha/members/bob'), memberProfile('bob', 'owner'));
  await assertFails(batch.commit());
});

test('members can set only their own valid display name', async () => {
  const aliceProfile = doc(db('alice'), 'families/alpha/members/alice');
  await assertSucceeds(updateDoc(aliceProfile, { displayName: 'Alice Ä' }));
  await assertFails(updateDoc(aliceProfile, { displayName: '' }));
  await assertFails(updateDoc(aliceProfile, { displayName: ' Alice' }));
  await assertFails(updateDoc(aliceProfile, { displayName: 'Alice ' }));
  await assertFails(updateDoc(aliceProfile, { displayName: 'a'.repeat(41) }));
  await assertFails(updateDoc(aliceProfile, {
    displayName: 'Alice', role: 'member',
  }));

  await invite();
  await assertSucceeds(join('bob', code, 'alpha', 'Bob'));
  await assertSucceeds(updateDoc(
    doc(db('bob'), 'families/alpha/members/bob'),
    { displayName: 'Bobby' },
  ));
  await assertFails(updateDoc(
    doc(db('alice'), 'families/alpha/members/bob'),
    { displayName: 'Manipuliert' },
  ));
});

test('a member can leave only by atomically removing both membership records', async () => {
  await invite();
  await join('bob');
  const bob = db('bob');
  const membershipRef = doc(bob, 'memberships/bob');
  const profileRef = doc(bob, 'families/alpha/members/bob');
  await assertFails(deleteDoc(membershipRef));
  await assertFails(deleteDoc(profileRef));
  const leave = writeBatch(bob);
  leave.delete(profileRef);
  leave.delete(membershipRef);
  await assertSucceeds(leave.commit());
  assert.equal((await getDoc(membershipRef)).exists(), false);
  await assertFails(getDoc(doc(bob, 'families/alpha')));

  const alice = db('alice');
  const ownerLeave = writeBatch(alice);
  ownerLeave.delete(doc(alice, 'families/alpha/members/alice'));
  ownerLeave.delete(doc(alice, 'memberships/alice'));
  await assertFails(ownerLeave.commit());
});

test('ownership transfer atomically changes owner id and both roles', async () => {
  await invite();
  await join('bob');
  await assertSucceeds(transfer(db('alice'), 'alpha', 'alice', 'bob'));
  const client = db('bob');
  assert.equal((await getDoc(doc(client, 'families/alpha'))).data().ownerId, 'bob');
  assert.equal((await getDoc(doc(client, 'families/alpha/members/alice'))).data().role, 'member');
  assert.equal((await getDoc(doc(client, 'families/alpha/members/bob'))).data().role, 'owner');
});

test('ownership transfer rejects unauthorized or incomplete transitions', async () => {
  await invite();
  await join('bob');

  await assertFails(transfer(db('bob'), 'alpha', 'alice', 'bob'));
  await assertFails(updateDoc(doc(db('alice'), 'families/alpha'), { ownerId: 'bob' }));
  await assertFails(updateDoc(
    doc(db('alice'), 'families/alpha/members/alice'),
    { role: 'member' },
  ));

  await assertFails(transfer(
    db('alice'), 'alpha', 'alice', 'bob', { name: 'Manipuliert' },
  ));

  const alice = db('alice');
  const inconsistent = writeBatch(alice);
  inconsistent.update(doc(alice, 'families/alpha'), { ownerId: 'bob' });
  inconsistent.update(doc(alice, 'families/alpha/members/bob'), { role: 'owner' });
  await assertFails(inconsistent.commit());
});

test('ownership transfer target must have matching profile and membership', async () => {
  await create('eve', 'other');
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(
      doc(context.firestore(), 'families/alpha/members/eve'),
      memberProfile('eve'),
    );
    await setDoc(
      doc(context.firestore(), 'families/alpha/members/charlie'),
      memberProfile('charlie'),
    );
  });
  await assertFails(transfer(db('alice'), 'alpha', 'alice', 'eve'));
  await assertFails(transfer(db('alice'), 'alpha', 'alice', 'charlie'));
  await assertFails(transfer(db('alice'), 'alpha', 'alice', 'missing'));
});

test('only owner can atomically dissolve an active family', async () => {
  await invite();
  await join('bob');
  await assertFails(updateDoc(doc(db('bob'), 'families/alpha'), {
    status: 'dissolved',
  }));
  await assertFails(updateDoc(doc(db('alice'), 'families/alpha'), {
    status: 'dissolved',
  }));
  await assertFails(dissolve(db('bob'), 'bob'));
  await assertSucceeds(dissolve(db('alice')));

  await env.withSecurityRulesDisabled(async context => {
    const snapshot = await getDoc(doc(context.firestore(), 'families/alpha'));
    assert.equal(snapshot.data().status, 'dissolved');
    assert.equal((await getDoc(doc(context.firestore(), 'memberships/alice'))).exists(), false);
  });
});

test('dissolved family blocks calendar data and lets stale members clean up', async () => {
  await invite();
  await join('bob');
  await setDoc(doc(db('alice'), 'families/alpha/events/one'), event());
  await assertSucceeds(dissolve(db('alice')));

  const bob = db('bob');
  await assertSucceeds(getDoc(doc(bob, 'families/alpha')));
  await assertFails(getDocs(collection(bob, 'families/alpha/members')));
  await assertFails(getDoc(doc(bob, 'families/alpha/events/one')));
  await assertFails(setDoc(doc(bob, 'families/alpha/events/two'), event('bob')));
  await assertFails(getDocs(collection(bob, 'families/alpha/activity')));
  await assertFails(getDoc(doc(bob, 'invitations', code)));

  const cleanup = writeBatch(bob);
  cleanup.delete(doc(bob, 'families/alpha/members/bob'));
  cleanup.delete(doc(bob, 'memberships/bob'));
  await assertSucceeds(cleanup.commit());
  await assertFails(getDoc(doc(bob, 'families/alpha')));
});

test('dissolved family rejects reactivation, transfer, join, and invitations', async () => {
  await invite();
  await join('bob');
  const secondCode = 'b'.repeat(32);
  await setDoc(doc(db('alice'), 'invitations', secondCode), invitation());
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), 'families/alpha'), {
      status: 'dissolved',
    });
  });

  await assertFails(updateDoc(doc(db('alice'), 'families/alpha'), {
    status: 'active',
  }));
  await assertFails(transfer(db('alice'), 'alpha', 'alice', 'bob'));
  await assertFails(join('charlie', secondCode));
  await assertFails(setDoc(
    doc(db('alice'), 'invitations', 'c'.repeat(32)),
    invitation(),
  ));
});

test('existing members can backfill only their own missing profile', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await deleteDoc(doc(context.firestore(), 'families/alpha/members/alice'));
  });
  const client = db('alice');
  const joinedAt = (await getDoc(doc(client, 'memberships/alice'))).data().joinedAt;
  await assertSucceeds(setDoc(
    doc(client, 'families/alpha/members/alice'),
    memberProfile('alice', 'owner', joinedAt),
  ));
  await env.withSecurityRulesDisabled(async context => {
    await deleteDoc(doc(context.firestore(), 'families/alpha/members/alice'));
  });
  await assertFails(setDoc(
    doc(client, 'families/alpha/members/alice'),
    memberProfile('mallory', 'owner', joinedAt),
  ));
});

test('racing recipients cannot both consume one invitation', async () => {
  await invite();
  const results = await Promise.allSettled([join('bob'), join('eve')]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
});

test('expired, revoked, mismatched and forged invitations fail', async () => {
  await invite();
  await assertFails(join('bob', code, 'other-family'));
  await assertFails(updateDoc(doc(db('alice'), 'invitations', code), { familyId: 'other-family' }));
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), 'invitations', code), {
      expiresAt: Timestamp.fromMillis(Date.now() - 1000),
    });
  });
  await assertFails(join('bob'));
  await deleteDoc(doc(db('alice'), 'invitations', code));
  await assertFails(join('bob'));
});

test('family isolation covers event reads, queries, writes and deletes', async () => {
  await create('eve', 'other');
  const path = 'families/alpha/events/one';
  await assertSucceeds(setDoc(doc(db('alice'), path), event()));
  await assertFails(getDoc(doc(db('eve'), path)));
  await assertFails(getDocs(collection(db('eve'), 'families/alpha/events')));
  await assertFails(setDoc(doc(db('eve'), path), event('eve')));
  await assertFails(deleteDoc(doc(db('eve'), path)));
  await assertFails(updateDoc(doc(db('alice'), 'families/alpha'), { ownerId: 'eve' }));
});

test('members synchronize, update and delete an event', async () => {
  await invite();
  await join('bob');
  const path = 'families/alpha/events/one';
  const client = db('bob');
  let stop;
  const received = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Listener timeout')), 8000);
    const events = query(collection(client, 'families/alpha/events'),
      where('year', '==', 2026), where('month', '==', 8), where('day', '==', 29));
    stop = onSnapshot(events, snapshot => {
      if (snapshot.docs.some(item => item.data().title === 'Ausflug')) {
        clearTimeout(timer);
        resolve();
      }
    }, error => { clearTimeout(timer); reject(error); });
  });
  try {
    await setDoc(doc(db('alice'), path), event());
    await received;
  } finally {
    if (stop) stop();
  }
  await assertSucceeds(updateDoc(doc(client, path), {
    title: 'Gemeinsam geändert', revision: 2, updatedBy: 'bob', updatedAt: serverTimestamp(),
  }));
  assert.equal((await getDoc(doc(db('alice'), path))).data().title, 'Gemeinsam geändert');
  await assertSucceeds(deleteDoc(doc(client, path)));
  assert.equal((await getDoc(doc(db('alice'), path))).exists(), false);
});

test('recurring event fields are validated without breaking old events', async () => {
  const client = db('alice');
  await assertSucceeds(setDoc(doc(client, 'families/alpha/events/old'), event()));
  await assertSucceeds(setDoc(doc(client, 'families/alpha/events/recurring'), {
    ...event(),
    recurrence: {
      frequency: 'monthly', endYear: 2027, endMonth: 8, endDay: 29,
    },
  }));
  await assertFails(setDoc(doc(client, 'families/alpha/events/bad-frequency'), {
    ...event(), recurrence: { frequency: 'sometimes' },
  }));
  await assertFails(setDoc(doc(client, 'families/alpha/events/bad-end'), {
    ...event(),
    recurrence: {
      frequency: 'daily', endYear: 2026, endMonth: 2, endDay: 30,
    },
  }));
  await assertFails(setDoc(doc(client, 'families/alpha/events/early-end'), {
    ...event(),
    recurrence: {
      frequency: 'daily', endYear: 2026, endMonth: 8, endDay: 28,
    },
  }));
});

test('all-day event field is optional, boolean, and disables reminders', async () => {
  const client = db('alice');
  await assertSucceeds(setDoc(
    doc(client, 'families/alpha/events/old-timed'),
    event(),
  ));
  await assertSucceeds(setDoc(
    doc(client, 'families/alpha/events/all-day'),
    {...event(), allDay: true},
  ));
  await assertSucceeds(setDoc(
    doc(client, 'families/alpha/events/explicit-timed'),
    {...event(), allDay: false, reminderMinutesBefore: 30},
  ));
  await assertFails(setDoc(
    doc(client, 'families/alpha/events/bad-all-day'),
    {...event(), allDay: 'yes'},
  ));
  await assertFails(setDoc(
    doc(client, 'families/alpha/events/all-day-reminder'),
    {...event(), allDay: true, reminderMinutesBefore: 30},
  ));
});

test('only supported reminder offsets are accepted while old events remain valid', async () => {
  const client = db('alice');
  for (const [index, reminderMinutesBefore] of [null, 0, 10, 15, 30, 60, 1440].entries()) {
    await assertSucceeds(setDoc(
      doc(client, `families/alpha/events/reminder-${index}`),
      {...event(), reminderMinutesBefore},
    ));
  }
  await assertFails(setDoc(
    doc(client, 'families/alpha/events/reminder-invalid'),
    {...event(), reminderMinutesBefore: 7},
  ));
  const withoutReminder = event();
  delete withoutReminder.reminderMinutesBefore;
  await assertSucceeds(setDoc(
    doc(client, 'families/alpha/events/reminder-old'),
    withoutReminder,
  ));
});

test('event member assignments are optional and bounded', async () => {
  const client = db('alice');
  await assertSucceeds(setDoc(
    doc(client, 'families/alpha/events/unassigned'),
    event(),
  ));
  await assertSucceeds(setDoc(
    doc(client, 'families/alpha/events/assigned'),
    {...event(), assignedMemberIds: ['alice', 'bob']},
  ));
  await assertFails(setDoc(
    doc(client, 'families/alpha/events/bad-assignments'),
    {...event(), assignedMemberIds: 'alice'},
  ));
  await assertFails(setDoc(
    doc(client, 'families/alpha/events/too-many-assignments'),
    {...event(), assignedMemberIds: Array.from({length: 51}, (_, i) => `member-${i}`)},
  ));
});

test('multi-day event dates are valid, complete, and incompatible with recurrence', async () => {
  const client = db('alice');
  const ref = suffix => doc(client, `families/alpha/events/${suffix}`);
  await assertSucceeds(setDoc(ref('trip'), {
    ...event(), endYear: 2026, endMonth: 9, endDay: 2, endMinute: 120,
  }));
  await assertFails(setDoc(ref('partial'), {...event(), endYear: 2026}));
  await assertFails(setDoc(ref('same-day'), {
    ...event(), endYear: 2026, endMonth: 8, endDay: 29,
  }));
  await assertFails(setDoc(ref('before'), {
    ...event(), endYear: 2026, endMonth: 8, endDay: 28,
  }));
  await assertFails(setDoc(ref('impossible'), {
    ...event(), endYear: 2026, endMonth: 9, endDay: 31,
  }));
  await assertFails(setDoc(ref('recurring'), {
    ...event(), endYear: 2026, endMonth: 9, endDay: 2,
    recurrence: {frequency: 'daily'},
  }));
});

test('creation and deletion activity is atomic, private, and authentic', async () => {
  await invite();
  await join('bob');
  await create('eve', 'other');
  const alice = db('alice'), eventRef = doc(alice, 'families/alpha/events', 'a'.repeat(32));
  const createBatch = writeBatch(alice);
  createBatch.set(eventRef, event());
  createBatch.set(doc(alice, 'families/alpha/activity/create'), activity('created'));
  await assertSucceeds(createBatch.commit());
  await assertSucceeds(getDocs(collection(db('bob'), 'families/alpha/activity')));
  await assertFails(getDocs(collection(db('eve'), 'families/alpha/activity')));
  await assertFails(setDoc(
    doc(db('bob'), 'families/alpha/activity/fake'),
    activity('deleted', 'bob'),
  ));
  const bob = db('bob');
  const deleteBatch = writeBatch(bob);
  deleteBatch.delete(doc(bob, 'families/alpha/events', 'a'.repeat(32)));
  deleteBatch.set(
    doc(bob, 'families/alpha/activity/delete'),
    activity('deleted', 'bob'),
  );
  await assertSucceeds(deleteBatch.commit());
  await assertFails(updateDoc(
    doc(db('alice'), 'families/alpha/activity/create'),
    { title: 'Gefälscht' },
  ));
});

test('invalid payloads, dates and skipped revisions are rejected', async () => {
  const client = db('alice');
  const ref = doc(client, 'families/alpha/events/one');
  const invalid = [
    { title: '' }, { title: 'x'.repeat(121) }, { notes: 'x'.repeat(2001) },
    { month: 2, day: 30 }, { month: 2, day: 29 }, { endMinute: 540 },
    { startMinute: -1 }, { endMinute: 1440 }, { revision: 2 },
    { updatedBy: 'bob' }, { unknown: true },
    { importance: 'urgent' }, { reminderMinutesBefore: 7 },
  ];
  for (const patch of invalid) await assertFails(setDoc(ref, { ...event(), ...patch }));
  await assertSucceeds(setDoc(ref, { ...event(), year: 2028, month: 2, day: 29 }));
  await assertFails(updateDoc(ref, { title: 'stale', updatedAt: serverTimestamp() }));
});

test('optimistic transaction refuses stale edits and resurrection', async () => {
  const client = db('alice');
  const ref = doc(client, 'families/alpha/events/one');
  await setDoc(ref, event());
  const save = expected => runTransaction(client, async transaction => {
    const snapshot = await transaction.get(ref);
    const revision = snapshot.exists() ? snapshot.data().revision : 0;
    if (revision !== expected) throw new Error('conflict');
    transaction.set(ref, { ...event(), revision: expected + 1 });
  });
  await save(1);
  await assert.rejects(save(1), /conflict/);
  await deleteDoc(ref);
  await assert.rejects(save(2), /conflict/);
});
