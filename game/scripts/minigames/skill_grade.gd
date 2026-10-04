class_name SkillChallengeGrade
## Classificação de precisão compartilhada (PERFEITO / ÓTIMO / BOM / ERROU).


static func label(offset: float) -> String:
	if offset <= 0.04:
		return "PERFEITO"
	if offset <= 0.12:
		return "ÓTIMO"
	if offset <= 0.25:
		return "BOM"
	return "ERROU"
