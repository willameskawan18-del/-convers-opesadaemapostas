# Jogos deste repositório

| Jogo | Pasta | Download (Windows) |
|---|---|---|
| **ALL WIN** — party game de game show (2–8) | `game/` | `builds/AllWin-Windows.zip` |
| **Leilão de Garagem** — compre galpões às cegas, abra e revenda (1–6) | `leilao/` | `builds/LeilaoDeGaragem-Windows.zip` |
| **Pesca no Abismo** — pesca cooperativa à noite em alto-mar (1–4) | `pesca/` | `builds/PescaNoAbismo-Windows.zip` |
| Bet Tycoon (antigo, preservado) | `legacy/bet_tycoon/` | — |

Material de loja (trailers, screenshots, cápsulas, textos PT/EN e passo a passo para publicar): pasta `marketing/`,
gerado pelos roteiros `tests/_media.tscn` de cada jogo (`-- shots <pasta>`, `-- keyart <pasta>`, `--write-movie x.avi ... -- trailer`).

Todos em Godot 4.7, com multiplayer por ENet (host autoritativo), UPnP para internet e testes headless em `tests/`.

## Leilão de Garagem
Dias com 3 galpões: ESPIAR (itens visíveis, boato, volumes) → LEILÃO AO VIVO (lances com "dou-lhe uma, duas") → ABRIR (revelação item a item)
→ VENDER no fim do dia (loja 85%, online 50–160%, guardar para coleção; cofres/baús misteriosos). Melhorias: Lanterna, Avaliador, Informante.
49 itens, 7 tipos de galpão, bots com personalidade.
**Nível loja:** lanterna interativa na espiada (mirar com o mouse e segurar para revelar; bateria limitada), PECHINCHA com o
comprador (chance depende do preço pedido; o COMPRADOR DO DIA paga mais por uma categoria), bots provocando em balões de fala,
carreira (títulos, catálogo dos 49 itens, 12 conquistas com IDs prontos para o Steamworks) em `scripts/ui/career_ui.gd`. Testes: `tests/match_test.tscn`, `tests/smoke_test.tscn`, `tests/net_test.tscn -- host|client`.

## Pesca no Abismo
Primeira pessoa no convés de um barco. Arremesso, fisgada e "puxar" com tensão da linha. 28 peixes em 3 zonas (raso, fundo, abismo).
Timão (pilotar), lanterna, caixa de peixes, porto com venda e 5 melhorias. Cota a cada 3 noites. Perigos: batidas e vazamentos,
tentáculo gigante, olhos na névoa (apagar a luz e parar), naufrágio. Coop até 4 (poses e estado do barco sincronizados).
**Nível loja:** bestiário (TAB e menu), 14 conquistas (IDs prontos para o Steamworks), tutorial com objetivos, clima por noite
(calmo / nevoeiro / TEMPESTADE com ondas maiores, chuva e relâmpagos, peixes mais raros), progresso salvo a cada amanhecer
e "CONTINUAR" no menu, peixe 3D saindo da água ao pescar e respingos. Ver `scripts/ui/meta_ui.gd` e `scripts/core/profile.gd`.
Testes: `tests/run_test.tscn`, `tests/fish_test.tscn`, `tests/smoke_test.tscn`, `tests/net_test.tscn -- host|client`.

---

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

## Loop da partida

MENU → LOBBY → INTRO ($1.000 para todos + MISSÃO SECRETA) →
9 rodadas por categoria: CONHECIMENTO → RISCO → HABILIDADE → SOCIAL → RISCO → HABILIDADE → CONHECIMENTO → SOCIAL → GRANDE RISCO (valores x2)
(com EVENTOS depois das rodadas 3 e 6) → MISSÕES REVELADAS → **ALL WIN** (rodada 10) → VENCEDOR + PRÊMIOS → JOGAR NOVAMENTE.
Cada rodada segue DECISÃO → INTERAÇÃO → RESULTADO → GANHO/PERDA, e muitas têm várias etapas (nova decisão a cada uma).
O sorteio evita repetir desafios na partida e os da partida anterior. Duração típica: 12–18 min.

## Desafios (20 no sorteio + eventos + ALL WIN)

| Categoria | Desafios |
|---|---|
| **Conhecimento** | Quiz (escolha a dificuldade: +500 / +1.500 / +3.000), Quiz Relâmpago (4 perguntas, o mais rápido ganha mais), Matemática (contas com dinheiro), Detetive (pistas lógicas, culpado único), Quem Está Mentindo? |
| **Habilidade** (jogados de verdade na tela) | Reflexo (+3.000/+2.000/+1.000), Precisão (aposta + barra: x5/x3/x2/x0), Tiro ao Alvo (normal, dourado, x2, negativo e alvo JACKPOT), Memória (sequência de cores), Corrida (aperte para correr, pule obstáculos; replay com todos) |
| **Risco** | Portas com pistas (uma é mentira), Bomba (abrir caixas ou parar), Escada do Risco (500→8.000, parar ou subir), Cartas (espiar e trocar; ganho, perda, multiplicador, proteção, troca, jackpot), Leilão aberto com informação secreta |
| **Social** | Votação (4 tipos), Alianças (recado + cooperar/trair, marca TRAIDOR), Hot Seat, Roubo (alvo + prova de precisão), Derrube o Rei |
| **Eventos** | Imposto, Bônus, Jackpot da plateia, Inflação (próxima rodada vale o dobro), Crash, Reviravolta, Troca de patrimônio (decisão do último), Robin Hood |

## Sistemas de economia e virada

- **SAFE CARD:** protege das perdas de um desafio de risco (usar agora ou guardar). Ganha-se em cartas, votação, leilão e reviravolta.
- **Jackpot progressivo:** $3.000, cresce 60% por rodada sem ganhador (máx. $25.000).
- **KING:** o líder usa coroa e é o alvo do "Derrube o Rei", de roubos e de votações.
- **VIRADA:** quem tem menos de 40% do líder (ou está zerado) ganha +50% nos ganhos da rodada.
- **Dívida limitada:** até -$5.000; quem está zerado joga com "ficha de resgate".
- **Missões secretas:** 10 tipos, bônus de $3.000+ antes do ALL WIN.
- **ALL WIN:** SAFE guarda 90% · ALL WIN: x4 (10%), x2 (35%) ou sobra 10% (55%).
- **Prêmios finais:** Mais rico, Mais arriscado, Maior multiplicador, Maior azar, Mais preciso, Mais vitórias, Maior recuperação.
- **Balanceamento** (`tests/balance_sim.gd`, 120 partidas simuladas): vencedores terminam com mediana ~$38k (p10 ~$19k, p90 ~$75k, máximo >$100k).

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
- **Rede (LAN / Internet):** host clica ABRIR SALA ONLINE; o jogo tenta abrir a porta 7777 (UDP) no roteador por **UPnP** e mostra o IP da internet. Se o roteador não permitir, Radmin VPN/ZeroTier/Hamachi funcionam (o lobby mostra o IP da VPN). Amigos usam JOIN GAME com o IP.
- **Steam (pendente):** precisa do plugin GodotSteam (GDExtension) e do `steam_api64.dll`; o download foi bloqueado pela rede deste ambiente. Com o plugin, usar o App ID 480 (Spacewar) para testes e `SteamMultiplayerPeer` no lugar do ENet no `NetworkManager`. Dinheiro, escolhas, resultados e entrada/saída são sincronizados; quem cai durante a partida passa a jogar no automático.
- Preparado para o futuro: reconexão (o estado completo já é enviado em `view`), servidor dedicado.

## Testes

```
cd game
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd        # lógica: dinheiro/dívida, categorias, 24 desafios com todas as etapas, 40 sementes (~28.700 verificações)
godot --headless --path . -s res://tests/balance_sim.gd      # simulação de economia (120 partidas)
godot --headless --path . res://tests/match_test.tscn        # 2 partidas completas só com bots + lobby/menu
godot --headless --path . res://tests/smoke_test.tscn        # fluxo com interface: PLAY, resultado, revanche, lobby com 2 humanos locais
godot --headless --path . res://tests/net_test.tscn -- host  # (em outro terminal: ... -- client) partida real via ENet
```

## Salvamento

`user://profile.json`: partidas, vitórias, maior patrimônio, melhor multiplicador, desafios vencidos, maior risco, último nome/personagem. `user://settings.cfg`: configurações.

## Ainda não implementado (próximos passos)

1. MERCADO de previsões ("quem vence a próxima rodada?") e caixas misteriosas com "segundo turno".
2. Reconexão de jogador no meio da partida e lista de salas.
3. Habilidades por personagem.
3. Tradução para inglês (textos já preparados para `tr()` / idioma nas configurações).
4. Áudio gravado (hoje os sons são sintetizados; arquivos em `game/audio/<nome>.ogg` substituem automaticamente).
5. Suporte a controle (gamepad) com cursor.
