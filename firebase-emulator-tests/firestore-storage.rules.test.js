import { existsSync, readFileSync } from 'node:fs';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';

const firestoreRulesPath = 'firestore.rules';
const storageRulesPath = 'storage.rules';
const hasRules = existsSync(firestoreRulesPath) && existsSync(storageRulesPath);

describe.skipIf(!hasRules)('Firebase emulator access rules', () => {
  let testEnv;

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: 'job-tracker-safety-net',
      firestore: {
        rules: readFileSync(firestoreRulesPath, 'utf8')
      },
      storage: {
        rules: readFileSync(storageRulesPath, 'utf8')
      }
    });
  });

  afterAll(async () => {
    await testEnv?.cleanup();
  });

  it('allows authenticated users to read their user profile and denies anonymous reads', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('crew-1').set({
        firstName: 'Crew',
        lastName: 'Tester',
        email: 'crew@example.com'
      });
    });

    const authed = testEnv.authenticatedContext('crew-1');
    const anon = testEnv.unauthenticatedContext();

    await assertSucceeds(authed.firestore().collection('users').doc('crew-1').get());
    await assertFails(anon.firestore().collection('users').doc('crew-1').get());
  });

  it('allows job participants to read jobs and denies non-participants', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('jobs').doc('job-1').set({
        address: '100 Safety Net Lane',
        participants: ['crew-1'],
        createdBy: 'crew-1'
      });
    });

    const participant = testEnv.authenticatedContext('crew-1');
    const outsider = testEnv.authenticatedContext('crew-2');

    await assertSucceeds(participant.firestore().collection('jobs').doc('job-1').get());
    await assertFails(outsider.firestore().collection('jobs').doc('job-1').get());
  });

  it('allows owners to upload job photos and denies anonymous storage writes', async () => {
    const authed = testEnv.authenticatedContext('crew-1');
    const anon = testEnv.unauthenticatedContext();
    const path = 'jobPhotos/job-1/photo.jpg';

    await assertSucceeds(authed.storage().ref(path).put(new Uint8Array([1, 2, 3]), { contentType: 'image/jpeg' }));
    await assertFails(anon.storage().ref(path).put(new Uint8Array([1, 2, 3]), { contentType: 'image/jpeg' }));
  });
});

if (!hasRules) {
  describe('Firebase emulator access rules', () => {
    it('skips until firestore.rules and storage.rules are added', () => {
      expect(hasRules).toBe(false);
    });
  });
}
