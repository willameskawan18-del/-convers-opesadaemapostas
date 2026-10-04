# ALL WIN — Status de desenvolvimento

Party game de **game show** para **2 a 8 jogadores**, feito em **Godot 4.7** (projeto em `game/`).
Dinheiro 100% fictício: não há apostas reais, depósitos, saques ou conversão para dinheiro real.

> O jogo anterior (Bet Tycoon) foi preservado em `legacy/bet_tycoon/` e no histórico do Git.

## Como jogar

- **Sem instalar nada (Windows):** baixe `builds/AllWin-Windows.zip`, extraia e abra `AllWin.exe`.
- **Pelo Godot 4.7:** Importar → `game/project.godot` → Editar → **F5**.

| Tela | O que faz |
|---|---|
| PLAY | Partida rápida: você + 3 bots |
| CREATE GAME | Lobby: jogadores locais (mesmo PC), bots, regras e sala online |
| JOIN GAME | Entra na sala de um amigo pelo IP (porta 7777) |
| HOW TO PLAY / SETTINGS / EXIT | Regras, configurações e sair |

Controles: mouse (ou Tab/Enter) nos botões · **Espaço/clique** no desafio de Reação (outros jogadores locais: Q, P, Z, M, A, L, X) · **Esc** pausa.

## Loop da partida (MVP completo)

MENU → LOBBY → INTRO ($1.000 para todos) → [RODADA → DESAFIO → DECISÃO → REVELAÇÃO → PLACAR] × N
(com **EVENTO ESPECIAL** depois de ~1/3 e ~2/3) → **ALL WIN** → VENCEDOR → RESULTADO → JOGAR NOVAMENTE / LOBBY / MENU.
Partida padrão: 8 rodadas (≈ 12–15 min). Configurável: 6, 8, 10 ou 12 rodadas; 15, 20 ou 30 s para decidir.

## Desafios

| Desafio | Regra |
|---|---|
| **As Portas** | A/B/C escondem x5, x2 e x0 da aposta da rodada. Escolha simultânea; portas abrem da pior para a melhor. |
| **Risco** | SAFE +$500 garantido · RISK 50% +$2.000 / 50% −$1.000 (revelação um a um com moeda). |
| **Reação** | Botão fica verde após tempo aleatório. 1º +$2.000, 2º +$1.000, 3º +$500; queimar a largada custa dinheiro. |
| **Leilão** | Prêmio misterioso com dica de faixa de valor; lances secretos; maior lance paga e leva (pode ser caixa vazia). |
| **Bluff** | Oferta secreta para cada um: PEGAR ou DOBRAR (+2× ou −4/3 da oferta). Revelação um por um. |
| **Evento especial** | Chuva de dinheiro, imposto do líder, Robin Hood, resgate do último, sorteio relâmpago, jackpot da plateia. |
| **ALL WIN (final)** | SAFE guarda 90% · ALL WIN: JACKPOT x4 (10%), DOBROU x2 (35%), PERDEU – sobra 10% (55%). Zerado joga com ficha de $1.000. |

Os valores crescem 20% por rodada. Quem zera continua jogando com "ficha de resgate" (sempre dá para virar).
Bots têm personalidade (Medroso foge do risco, Maluco e Apostador arriscam, quem está atrás arrisca mais).

## Arquitetura

```
game/
  scenes/main.tscn            cena principal (arena + interface)
  scripts/managers/           GameManager (autoload Game), MatchRunner (fluxo), RoundManager,
                              PlayerManager/PlayerState, MoneyManager, MinigameManager, MatchContext
  scripts/minigames/          Challenge (base), ChallengeDef (Resource) e um script por desafio
  data/challenges/*.tres      definição de cada desafio (título, regras, cor, tipo de entrada, script)
  scripts/net/                NetworkManager (autoload Net, ENet host/cliente)
  scripts/arena/              Arena 3D, púlpitos, diretor de câmera, shaders (piso LED, lâmpadas, plateia)
  scripts/players/            personagens cartoon procedurais
  scripts/ui/                 UIManager, HUD, painel de decisão (com "passa o controle"), revelações,
                              menu, lobby, resultado, diálogos, ShowDirector (câmera/luz/som por evento)
  scripts/core/               Settings, Audio (sintetizado), Profile (estatísticas), Fmt, GameData
  tests/                      testes de lógica, partida com bots, interface e rede (2 processos)
```

**Fluxo de dados:** a lógica roda só no host. Ações chegam por `Game.submit_action()` (RPC para o host, que valida o dono do jogador). O host publica eventos (`view`, `phase`, `money`, `step`, `private`...) que cada máquina aplica no seu espelho e transforma em sinais — a interface só escuta sinais, então jogo local e online usam exatamente o mesmo caminho. Informação secreta (oferta do Bluff, opções) vai só para a máquina dona do jogador.

**Novo desafio:** crie `scripts/minigames/novo.gd` estendendo `Challenge` (opções, ação de bot, `resolve()` devolvendo passos de revelação), um `.tres` em `data/challenges/` e adicione o caminho em `MinigameManager.CHALLENGES`.

## Multiplayer

- **Local (mesmo PC):** vários humanos no lobby; nas escolhas secretas aparece uma cortina "VEZ DE ..." para cada um. Na Reação todos jogam juntos, cada um com sua tecla.
- **Rede (LAN / Internet com porta 7777 liberada):** host clica ABRIR SALA ONLINE; amigos usam JOIN GAME com o IP. Dinheiro, escolhas, resultados e entrada/saída são sincronizados; quem cai durante a partida passa a jogar no automático.
- Preparado para o futuro: reconexão (o estado completo já é enviado em `view`), servidor dedicado.

## Testes

```
cd game
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd        # lógica (dinheiro, ranking, sequência, 5 desafios + evento + ALL WIN, 40 sementes)
godot --headless --path . res://tests/match_test.tscn        # 2 partidas completas só com bots + lobby/menu
godot --headless --path . res://tests/smoke_test.tscn        # fluxo com interface: PLAY, resultado, revanche, lobby com 2 humanos locais
godot --headless --path . res://tests/net_test.tscn -- host  # (em outro terminal: ... -- client) partida real via ENet
```

## Salvamento

`user://profile.json`: partidas, vitórias, maior patrimônio, melhor multiplicador, desafios vencidos, maior risco, último nome/personagem. `user://settings.cfg`: configurações.

## Ainda não implementado (próximos passos)

1. Reconexão de jogador no meio da partida e lista de salas.
2. Mais desafios (o sistema de `ChallengeDef` já está pronto) e habilidades por personagem.
3. Tradução para inglês (textos já preparados para `tr()` / idioma nas configurações).
4. Áudio gravado (hoje os sons são sintetizados; arquivos em `game/audio/<nome>.ogg` substituem automaticamente).
5. Suporte a controle (gamepad) com cursor.
