# Papo Reto

Ditado por voz para macOS, focado em PT-BR, 100% local. Segura `Fn`, fala, solta: o texto aparece no cursor.

Em desenvolvimento: por enquanto o app só aparece na menu bar.

## Compilar e rodar
Requer macOS 13+ e as Command Line Tools (`xcode-select --install`) ou o Xcode.

```sh
make test   # testes + 100% de cobertura de linha no PapoRetoCore
make app    # gera build/PapoReto.app (assinatura ad-hoc)
make run    # gera e abre o app
```

## Licença
MIT. Veja [LICENSE](LICENSE).
