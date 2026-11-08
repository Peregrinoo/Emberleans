#!/usr/bin/env bash
# Captura as telas do EmberLens no simulador para o README.
#
# Uso (na raiz do repositório, com o app rodando no simulador):
#   bash docs/screenshots/capture.sh
#
# O script pausa antes de cada captura: deixe o app na tela indicada e pressione Enter.
# Para pular uma tela, digite "s" e Enter.
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
OUT="$(cd "$(dirname "$0")" && pwd)"
SIM=booted

# Barra de status limpa (9:41, bateria cheia, sinal completo).
xcrun simctl status_bar "$SIM" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName "" >/dev/null

shot() {
  local file="$1" instruction="$2"
  printf '\n▸ %s\n  Enter para capturar · s para pular: ' "$instruction"
  read -r answer
  if [[ "$answer" == "s" ]]; then echo "  pulado"; return; fi
  xcrun simctl io "$SIM" screenshot --type=png "$OUT/$file" >/dev/null
  echo "  ✓ $file"
}

xcrun simctl ui "$SIM" appearance light
echo "Modo claro"
shot 01-home.png            "Tela inicial (Home)"
shot 02-source-sheet.png    "Folha 'Analisar imagem' aberta (Câmera / Fotos)"
shot 03-preview.png         "Prévia com uma foto de queimadura, antes de analisar"
shot 04-questionnaire.png   "Pergunta 1: 'Como aconteceu a lesão?'"
shot 05-warning-signs.png   "Pergunta 3: 'Existe algum sinal de alerta?'"
shot 06-result.png          "Resultado no topo (foto + classificação) — Calor › Braços › Nenhum › Agora há pouco"
shot 07-guidance.png        "Mesmo resultado, rolado até 'O que fazer agora'"
shot 08-seek-care.png       "Mesmo resultado, rolado até 'Quando procurar atendimento'"
shot 09-emergency.png       "Emergência: Corte › Tronco › Sangramento intenso"
shot 10-about.png           "Tela Sobre"

xcrun simctl ui "$SIM" appearance dark
echo
echo "Modo escuro"
shot 11-home-dark.png       "Tela inicial (Home) no modo escuro"
shot 12-result-dark.png     "Resultado no modo escuro (topo)"

xcrun simctl ui "$SIM" appearance light
xcrun simctl status_bar "$SIM" clear >/dev/null
echo
echo "Pronto. Capturas em $OUT"
