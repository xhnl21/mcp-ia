import { execFileSync } from 'node:child_process'
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

// La regla del pre-commit: un .ts nuevo de src/ necesita una prueba que lo importe o un «sin-prueba:» con el motivo.
const revisar = (...archivos: string[]) => {
  try {
    execFileSync('sh', ['scripts/check_archivos_con_prueba.sh', ...archivos], { encoding: 'utf8' })
    return 0
  } catch (e) {
    return (e as { status: number }).status
  }
}

describe('check_archivos_con_prueba.sh', () => {
  it('deja pasar lo que una prueba importa, los .d.ts y lo que no es src/', () => {
    expect(revisar('src/game/GolpeMundo.ts', 'src/game/data/golpe.ts')).toBe(0)
    expect(revisar('src/types/phaser.d.ts', 'tests/unit/golpe.spec.ts', 'docs/x.md')).toBe(0)
  })

  it('frena un archivo que ninguna prueba importa, salvo que diga por qué', () => {
    const dir = mkdtempSync(join('src', 'game', 'tmp-prueba-'))
    try {
      const sin = join(dir, 'SinPrueba.ts'), exento = join(dir, 'Exento.ts')
      writeFileSync(sin, 'export const x = 1\n')
      writeFileSync(exento, '// sin-prueba: solo dibuja, se prueba con Cypress\nexport const y = 2\n')
      expect(revisar(sin)).toBe(1)
      expect(revisar(exento)).toBe(0)
    } finally {
      rmSync(dir, { recursive: true })
    }
  })
})
