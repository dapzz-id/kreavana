class OpportunityModel {
  final int id;
  final String title;
  final String? description;
  final String pihakSlug;
  final String? location;
  final String? deadline;
  final String? budgetRange;
  final String status;
  final int postedBy;
  final String? createdAt;

  OpportunityModel({
    required this.id,
    required this.title,
    this.description,
    required this.pihakSlug,
    this.location,
    this.deadline,
    this.budgetRange,
    this.status = 'open',
    required this.postedBy,
    this.createdAt,
  });

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    return OpportunityModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? '',
      description: json['description'],
      pihakSlug: json['pihak_slug'] ?? '',
      location: json['location'],
      deadline: json['deadline'],
      budgetRange: json['budget_range'],
      status: json['status'] ?? 'open',
      postedBy: json['posted_by'] is int
          ? json['posted_by']
          : int.parse(json['posted_by'].toString()),
      createdAt: json['created_at'],
    );
  }
}
