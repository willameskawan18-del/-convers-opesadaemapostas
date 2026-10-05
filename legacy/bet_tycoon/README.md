# BET TYCOON — Da Banca ao Cassino

Jogo 3D de simulação/tycoon feito em **Godot 4.7** (compatível com 4.3+).
Todo dinheiro e todas as apostas são fictícios.

## Como jogar
1. Instale o Godot 4.7 (versão padrão, não precisa da .NET).
2. No Gerenciador de Projetos do Godot clique em **Importar** e selecione `game/project.godot`.
3. Clique em **Importar e Editar** e depois aperte **F5** (ou o botão ▶ no canto superior direito).

## Controles
| Tecla | Ação |
|---|---|
| WASD / setas | Andar |
| Shift | Correr |
| Espaço | Pular |
| Mouse | Câmera |
| E | Interagir |
| TAB | Celular |
| B | Administração |
| T | Velocidade do tempo (x1/x2/x4) |
| V | Alternar 3ª/1ª pessoa |
| F5 / F9 | Salvar / Carregar rápido |
| ESC | Pausa / fechar janelas |
| F12 | Painel de debug (só rodando pelo editor) |

## O que tem no jogo
Cidade 3D com trânsito e pedestres, apostas esportivas simuladas, trabalhos, banca que evolui em 6 estágios até o Grande Cassino,
clientes com IA e fila, funcionários, reputação, concorrentes com IA (que podem falir ou ser comprados), promoções, eventos,
imóveis, licenças, banco e cheque especial, falência com modo recuperação, operação online e **19 jogos de cassino jogáveis**
(21, roleta, bacará, Bac Bo, dragão & tigre, sic bo, roda da fortuna, aviãozinho, campo minado, plinko, dados, maior ou menor,
keno, bingo, raspadinha, caça-níqueis, jackpot e video poker). Veja `../DEVELOPMENT_STATUS.md`.

## Testes automáticos
```
godot --headless --path game -s res://tests/run_tests.gd      # simulação
godot --headless --path game res://tests/smoke_test.tscn      # cena completa
godot --headless --path game -s res://tests/campaign_bot.gd   # robô joga a campanha inteira
```
