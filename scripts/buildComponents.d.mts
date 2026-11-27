import type { ComponentEntryPayload } from '../src/types/elm';

export function buildComponents(dir: string): Promise<readonly ComponentEntryPayload[]>;
