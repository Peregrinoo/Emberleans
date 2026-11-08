# Orientações do EmberLens: regras e fontes

Este documento explica como o EmberLens monta as orientações de primeiros cuidados e de onde vem cada texto. O objetivo é que qualquer pessoa consiga revisar o conteúdo.

Última revisão do conteúdo: novembro de 2026.

## Princípios

1. **A fotografia não decide os cuidados.** As orientações são calculadas por `GuidanceEngine.evaluate(_:)`, que recebe apenas `QuestionnaireAnswers`. O resultado da classificação nem é um parâmetro. A análise visual aparece depois, como informação complementar, com o aviso de que é experimental e de que não foi usada nas orientações.
2. **Emergência primeiro.** As regras de emergência rodam antes das outras e funcionam com respostas parciais. Um único sinal de alerta já interrompe o questionário.
3. **Falta de informação não significa ausência de risco.** "Não sei informar" na pergunta sobre sinais de alerta aumenta a urgência para "avaliação profissional" e mostra um aviso. Se a causa é desconhecida, nenhum cuidado específico é apresentado.
4. **Sem diagnóstico, sem medicamentos, sem garantias.** Nenhum texto diagnostica, indica medicamentos, estima profundidade ou gravidade, nem afirma que a lesão é segura ou que dispensa atendimento. Um teste automatizado procura termos proibidos em todas as combinações de respostas.
5. **Conteúdo estático e revisável.** Todos os textos estão em `GuidanceContent.swift`, e cada item lista as fontes (`GuidanceSource`). Não há geração dinâmica por IA.

## Regras (`GuidanceRule`)

| Regra | Quando se aplica | Resultado |
|---|---|---|
| `emergencyWarningSign` | Qualquer sinal na pergunta 3 | Emergência. Dificuldade para respirar ou sangramento intenso: "Ligue agora para o SAMU 192". Demais sinais: "Procure atendimento médico imediatamente". |
| `emergencyElectricity` | Causa: eletricidade | Emergência (ligar 192). O primeiro passo é a segurança de quem ajuda. |
| `emergencyChemical` | Causa: produto químico | Emergência (atendimento imediato), com enxágue de pelo menos 20 minutos. |
| `insufficientUnknownCause` | Causa: "Não sei informar" e nenhum sinal de alerta | Sem passos específicos. Recomenda avaliação profissional e mostra a lista de sinais. |
| `heatRecentFirstAid` | Calor, agora há pouco, hoje ou não sei | Resfriar por 20 minutos (condicionado a "até 3 horas" quando o horário não é exato), retirar acessórios, proteger a pele, manter aquecido, observar. |
| `heatOlderCare` | Calor, há alguns dias | Sem resfriamento (só é indicado até 3 horas depois). Manter protegido e observar sinais de infecção. |
| `cutRecentFirstAid` | Corte ou arranhão recente | Pressionar por 10 minutos, limpar com água, cobrir, observar. |
| `cutOlderCare` | Corte ou arranhão há alguns dias | Manter limpo e coberto, observar sinais de infecção. |
| `impactRecentFirstAid` | Pancada recente | Frio protegido por até 15 minutos a cada hora, elevar, poupar a região, observar. |
| `impactOlderCare` | Pancada há alguns dias | Observar e procurar atendimento se surgir algum sinal. |
| `sensitiveLocation` | Rosto ou pescoço, mãos ou pés, região íntima | Aviso e urgência mínima de avaliação profissional. |
| `warningSignsUnknown` | Pergunta 3: "Não sei informar" | Aviso e urgência mínima de avaliação profissional. |
| `onsetUnknown` | Pergunta 4: "Não sei informar" | Aviso de que algumas orientações dependem do tempo decorrido. |

A lista "Quando procurar atendimento" aparece sempre, em todas as situações.

## Fontes

| Identificador | Fonte | Usada para |
|---|---|---|
| `nhsBurns` | NHS, *Burns and scalds*: https://www.nhs.uk/conditions/burns-and-scalds/ | Resfriamento por 20 minutos e até 3 horas; nada de gelo, cremes ou manteiga; retirar acessórios; cobrir com filme plástico ou pano limpo; atendimento para queimaduras químicas, elétricas, extensas ou em regiões sensíveis. |
| `nhsCuts` | NHS, *Cuts and grazes*: https://www.nhs.uk/conditions/cuts-and-grazes/ | Pressão por 10 minutos e elevação; limpeza com água; curativo; sinais de infecção; ferida suja ou mordida; sangramento que não para. |
| `britishRedCrossBurns` | Cruz Vermelha Britânica, *First aid for burns*: https://www.redcross.org.uk/first-aid/learn-first-aid/burns | Resfriamento; não usar manteiga, creme ou pasta de dente; queimaduras em bebês e crianças. |
| `americanBurnAssociation` | American Burn Association, *First Aid for Minor Burns* (2020): https://ameriburn.org/ | Não aplicar gelo; não resfriar demais (parar se tremer); não estourar bolhas; cobrir sem apertar. |
| `healthdirectChemicalBurns` | healthdirect, *Chemical burns*: https://www.healthdirect.gov.au/chemical-burns | Enxágue por pelo menos 20 minutos; retirar roupas sem puxar o que está grudado; proteger quem ajuda. |
| `healthwiseChemicalBurns` | Healthwise/Cigna, *First Aid for Chemical Burns*: https://www.cigna.com/knowledge-center/hw/first-aid-for-chemical-burns-sig256946 | Retirar pó seco antes de molhar; levar a embalagem do produto. |
| `stJohnElectricShock` | St John Ambulance Australia, *Electric shock*: https://stjohn.org.au/app/uploads/2025/08/Fact-sheets_electric-shock.pdf | Desligar a energia antes de ajudar; não se aproximar de alta tensão. |
| `medlinePlusBruises` | MedlinePlus, *Bruises*: https://medlineplus.gov/ency/article/007213.htm | Gelo envolvido em pano, até 15 minutos por hora; elevar; poupar a região. |
| `healthNZBruises` | Health New Zealand, *Bruises*: https://info.health.nz/conditions-treatments/emergencies-and-first-aid/bruises | Atendimento se houver muito inchaço ou dor, dificuldade para mover a região ou uso de anticoagulante. |
| `emberLensConservativeRule` | Regra do próprio app | Na dúvida, recomendar atendimento; dificuldade para respirar sempre leva ao 192. |

## Limitações conhecidas

- As fontes são majoritariamente internacionais (Reino Unido, EUA, Austrália, Nova Zelândia). O número de emergência usado é o do SAMU (192, Brasil). Uma revisão futura deve incluir material do Ministério da Saúde.
- Analgésicos citados por algumas fontes foram omitidos de propósito: o app não indica medicamentos.
- O conteúdo deve ser revisado por um profissional de saúde antes de qualquer uso fora de um contexto de portfólio.
