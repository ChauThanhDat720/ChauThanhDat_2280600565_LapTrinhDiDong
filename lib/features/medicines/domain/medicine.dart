class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.brandNames,
    required this.activeIngredient,
    required this.category,
    required this.dosageForm,
    required this.indications,
    required this.dosageInstructions,
    required this.sideEffects,
    required this.contraindications,
    this.precautions,
  });

  final String id;
  final String name;
  final String brandNames;
  final String activeIngredient;
  final String category;
  final String dosageForm;
  final String indications;
  final String dosageInstructions;
  final String sideEffects;
  final String contraindications;
  final String? precautions;

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      brandNames: json['brandNames'] as String? ?? json['brand_names'] as String? ?? '',
      activeIngredient: json['activeIngredient'] as String? ?? json['active_ingredient'] as String? ?? '',
      category: json['category'] as String? ?? '',
      dosageForm: json['dosageForm'] as String? ?? json['dosage_form'] as String? ?? '',
      indications: json['indications'] as String? ?? '',
      dosageInstructions: json['dosageInstructions'] as String? ?? json['dosage_instructions'] as String? ?? '',
      sideEffects: json['sideEffects'] as String? ?? json['side_effects'] as String? ?? '',
      contraindications: json['contraindications'] as String? ?? '',
      precautions: json['precautions'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brandNames': brandNames,
        'activeIngredient': activeIngredient,
        'category': category,
        'dosageForm': dosageForm,
        'indications': indications,
        'dosageInstructions': dosageInstructions,
        'sideEffects': sideEffects,
        'contraindications': contraindications,
        'precautions': precautions,
      };
}
