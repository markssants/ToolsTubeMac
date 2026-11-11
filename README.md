# ToolsTube

App nativo para macOS (SwiftUI) para baixar vídeos do YouTube, converter e cortar arquivos.

- **Baixar** — Vídeo Único, Vários Vídeos, Playlist (uma ou várias) e Fila
- **Conversor** — Converter Único, Converter Vários (opções por arquivo) e Fila
- **Corte** — Cortar Único (com player e marcação de início/fim), Cortar Vários e Fila

## Requisitos

- macOS 14+
- `brew install yt-dlp ffmpeg`

## Compilar

```sh
./scripts/build_app.sh          # gera build/ToolsTube.app
cp -R build/ToolsTube.app /Applications/
```

Para desenvolvimento: `swift run`.
Teste de ponta a ponta (baixa, converte e corta um vídeo curto): `swift build && .build/debug/ToolsTube --selftest /tmp/tt`.
