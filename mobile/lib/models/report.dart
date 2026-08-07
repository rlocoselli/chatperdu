class Report {
  final String id, name, status, place, color, description, image;
  const Report(
      {required this.id,
      required this.name,
      required this.status,
      required this.place,
      required this.color,
      required this.description,
      required this.image});
  factory Report.fromJson(Map<String, dynamic> j) => Report(
      id: '${j['id']}',
      name: j['name'] ?? '',
      status: j['status'] ?? 'Perdu',
      place: j['place'] ?? '',
      color: j['color'] ?? '',
      description: j['desc'] ?? '',
      image: j['image'] ?? '');
}
