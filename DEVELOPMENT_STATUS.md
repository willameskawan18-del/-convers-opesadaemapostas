# BET TYCOON — Da Banca ao Cassino · Status de desenvolvimento

Jogo 3D de simulação/tycoon em **Godot 4.7** (projeto em `game/`). Dinheiro, apostas e jogos são 100% fictícios; nada se conecta a apostas ou pagamentos reais.

## Como executar

**Jogar sem instalar nada (Windows):** baixe `builds/BetTycoon-Windows.zip`, extraia e abra `BetTycoon.exe`.

**Pelo Godot 4.7:** Gerenciador de Projetos → **Importar** → `game/project.godot` → **Importar e Editar** → **F5**.

## Controles

| Tecla | Ação |
|---|---|
| WASD / setas | Andar |
| Shift | Correr |
| Espaço | Pular |
| Mouse | Câmera |
| E | Interagir |
| Tab | Celular |
| B | Administração |
| T | Velocidade do tempo (x1/x2/x4) |
| V | 3ª/1ª pessoa |
| F5 / F9 | Salvar / carregar |
| Esc | Pausa / fechar janelas |
| F12 | Painel de debug (só em builds de desenvolvimento ou com `--dev`) |

## Sistemas implementados (funcionais e testados)

- **Mundo 3D:** cidade com 3 colunas de quarteirões, avenida, ruas transversais e ruas de trás, calçadas com meio-fio, praça com fonte animada, banco, mercado, loja, depósito, prédio do jogador, 8 casas, 3 concorrentes, 4 lotes para o negócio do jogador, outdoors, semáforos, postes, lixeiras e hidrantes.
- **Gráficos:** materiais procedurais por shader (asfalto, ladrilho, grama, reboco, tijolo, concreto, metal ondulado, vidro com janelas que acendem à noite, telhas, folhagem com vento, água), céu procedural com nuvens, sol, lua e estrelas, ciclo dia/noite, AgX, SSAO, SSIL, bloom, névoa atmosférica, vinheta e profundidade de campo no menu.
- **Vida na cidade:** 18 pedestres com IA (andar, parar, conversar, entrar em lojas), trânsito na avenida que para no sinal vermelho, atrás de outros carros e diante do jogador.
- **Personagem:** terceira pessoa com SpringArm (não atravessa paredes), câmera mais próxima em ambientes internos, alternância para primeira pessoa, correr, pular, interagir, passos com som.
- **Economia central** (`EconomySystem`): toda entrada e saída tem categoria; receitas, despesas, investimentos e financiamento separados; patrimônio líquido; relatório diário com análise (maior custo, maior problema, melhor resultado).
- **Apostas simuladas:** futebol (1x2), basquete, tênis, vôlei, MMA, e-sports, corrida de kart e **corrida de cavalos rápida a cada 30 minutos** (animada); app com abas por esporte e bilhete em 3 passos; probabilidade interna, odds com margem, notícias que mudam as chances reais (apostas de valor), clássicos/finais com mais procura.
- **Trabalhos:** 6 trabalhos (entregas com marcador no mapa, carga, turnos com tempo acelerado), recompensa variável, prazo, dificuldade, horários e tempo de espera.
- **Banca e expansão:** 6 estágios (Pequena Banca → Banca Profissional → Salão → Grande Salão → Galpão → Grande Cassino), cada um com visual 3D próprio, capacidade, guichês, limite de funcionários, demanda, custos e requisitos (nível, reputação, licença, imóvel).
- **Equipamentos:** 16 equipamentos de banca + 21 jogos de cassino, com custo, manutenção, energia, efeitos, quebras e conserto.
- **Clientes com IA:** 10 tipos (casual, entusiasta, profissional, VIP, cauteloso, agressivo, impulsivo, desconfiado, novato, problemático) com dinheiro, confiança, risco, fidelidade, frequência, satisfação, esporte preferido, sensibilidade a promoções e odds, paciência. Fluxo de visita: andando → entrando → fila → atendimento → apostando → saindo, visível em 3D.
- **Fila e atendimento:** o jogador atende atrás do balcão; atendentes e terminais de autoatendimento atendem sozinhos; desistências, lotação e reputação.
- **Funcionários:** 7 funções (atendente, caixa, segurança, analista, gerente, especialista, crupiê) com salário, eficiência, experiência, nível, satisfação, chance de erro, perfil; estados IDLE/MOVING/WORKING/RESTING/ERROR; contratação, treino, aumento, demissão, pedidos de aumento.
- **Livro de apostas da banca:** exposição por evento, pior cenário, risco (BAIXO/MÉDIO/ALTO/CRÍTICO), margem configurável, aposta máxima, **limite de exposição**, suspensão de resultados, balanceamento automático (com analista), precificação com erro (clientes profissionais exploram odds mal calculadas).
- **Reputação** (0–100) com motivos registrados por dia.
- **XP e níveis** com títulos (Apostador → Magnata do Entretenimento) e desbloqueios.
- **Imóveis:** alugar, comprar, vender, valorização, casas para renda passiva, imóvel antigo vira renda após a mudança.
- **Licenças:** 6 licenças fictícias com requisitos de dinheiro, nível, reputação, estágio, equipamentos e licenças anteriores.
- **Banco:** 5 linhas de crédito, parcelas diárias, quitação antecipada, score e limite de crédito, **cheque especial** com juros.
- **Falência e modo recuperação:** liquidação de ativos, dívida renegociada, perda de licenças avançadas, campanha volta ao capítulo 3, trabalhos com bônus.
- **Concorrentes com IA:** Banca do Zé, Lucky Bet e Royal Apostas com capital, reputação, odds, porte, estratégia e agressividade; máquina de estados MONITOR → ANALYZE → PROMOTION/EXPANSION → NORMAL_OPERATION; participação de mercado; concorrentes podem falir; **aquisição** vira filial com renda diária; letreiros mudam no mundo.
- **Promoções:** 9 promoções com custo, duração, alcance, reputação e retorno estimado.
- **Eventos aleatórios:** 21 eventos (com decisões), incluindo fraude abstrata, documento inconsistente, roubo, conflito, fiscalização, quedas de internet e equipamentos, oportunidades.
- **Cassino do dono:** 21 jogos como equipamentos com margem e volatilidade próprias; mesas exigem crupiê; estatística por jogo.
- **Cassino jogável (19 jogos):** 21, roleta europeia, bacará (regra da 3ª carta), bacará de dados (Bac Bo), dragão & tigre, sic bo, roda da fortuna, aviãozinho (crash), campo minado, plinko, dados acima/abaixo, maior ou menor, keno, bingo, raspadinha, caça-níquel clássico, video slot com curinga, jackpot progressivo e video poker. RTP calibrado e testado. Salões na Royal Apostas e na Lucky Bet; cassino online no celular a partir do nível 3.
- **Operação online:** site/app em 5 níveis, usuários, capacidade de servidores, quedas por sobrecarga, marketing, suporte, segurança digital, ataques abstratos, reputação online.
- **Campanha:** 11 capítulos + 10 objetivos secundários, tutorial integrado (dicas somem após o capítulo 4), marcador dourado no mundo apontando o objetivo, tela de vitória e modo pós-campanha.
- **Celular:** Banco, Apostas, Notícias, Empregos, Administração, Mercado, Mensagens, Contatos, Objetivos, Mapa, Operação Online, Cassino.
- **Administração:** Visão Geral, Finanças (com custos fixos previstos), Apostas/Exposição, Clientes, Funcionários, Equipamentos, Propriedades/Expansão, Licenças, Promoções, Risco, Reputação, Concorrência, Cassino.
- **Save/Load:** JSON com checksum, arquivo temporário e backup automático (`.bak`); salvamento automático no fim do dia; F5/F9.
- **Menus:** principal (Continuar, Novo Jogo, Configurações, Sair), pausa, configurações (resolução, tela cheia, VSync, qualidade, sombras, distância de renderização, volumes, sensibilidade, inverter Y).
- **Áudio:** sons sintetizados (placeholders funcionais) para interface, notificações, caixa, passos, máquinas, vitória/derrota, música e ambiente; arquivos em `game/audio/<nome>.ogg|wav` substituem automaticamente.
- **Debug (F12):** dinheiro, XP, avançar hora/dia, completar objetivo, reputação, falência, empréstimo, licenças, gerar evento, gerar cliente.

- **Cassino Estrela (aberto desde o início):** cassino de esquina onde se entra a pé, com 5 áreas sinalizadas (Máquinas, Mesas de Cartas, Roleta & Roda, Jogos Rápidos, Sorte & Bingo), cada máquina/mesa com placa do jogo; aperte E para jogar.
- **Minimapa** no canto superior direito com ruas, prédios, locais e objetivo.
- **Movimento:** o personagem sobe degraus e meio-fios sozinho (até 45 cm); só precisa pular obstáculos maiores.
- **Dificuldade inicial:** licença, aluguel e equipamentos mais caros; só 1 empréstimo ativo até o nível 6 (2 até o 12, 3 depois).
- **Bairro brasileiro:** padaria, farmácia, lanchonete, mercadinho, caixas d'água, postes com fiação, palmeiras, ônibus circular, quintais, estacionamento, telões e letreiro de lâmpadas na banca.

## Parcialmente implementado

- **Cassino 3D:** as máquinas e mesas aparecem no estabelecimento, mas os clientes do cassino são simulados (receita por hora), sem NPCs sentados nas mesas.
- **Operação online:** não tem representação 3D própria (sala de servidores).
- **Animações:** procedurais (caminhada, respiração); sem animações de interação (sentar, digitar).
- **Áudio:** placeholders sintetizados; falta trilha e efeitos gravados.

## Ainda não implementado

- Apostas múltiplas e ao vivo (a estrutura de bilhete já guarda o campo `market`).
- Cooperativo (a simulação é separada do personagem para facilitar no futuro).
- Localização para outros idiomas.

## Como testar

```
cd game
godot --headless --path . --import                          # registra as classes
godot --headless --path . -s res://tests/run_tests.gd       # 200+ verificações da simulação
godot --headless --path . res://tests/smoke_test.tscn       # fluxo completo na cena (UI + 3D + cassino)
godot --headless --path . -s res://tests/campaign_bot.gd    # robô joga a campanha e imprime a progressão
```

Os testes cobrem economia, apostas, liquidação, RTP dos jogos de cassino, trabalhos, empréstimos, missões/XP, save/load (inclusive save corrompido), banca de 10 dias, concorrência, eventos e promoções, além do fluxo jogável completo na cena.

## Limitações conhecidas

- O balanceamento foi ajustado com o robô de campanha; jogadores muito agressivos (margem baixa, aposta máxima alta, pouco caixa) podem ter dias de prejuízo grandes. É intencional: use o limite de exposição.
- Em computadores sem Vulkan, o Godot cai para o modo Compatibilidade (sem SSAO/SSIL).
- O executável Windows não é assinado digitalmente (aviso do SmartScreen).

## Próximos sistemas recomendados

1. NPCs jogando nas máquinas e mesas do cassino do jogador.
2. Apostas múltiplas e ao vivo.
3. Interior visitável dos concorrentes.
4. Trilha sonora e efeitos gravados.
6. Conquistas e estatísticas de carreira.
