class SellerItem {
  final String name;
  final String image;
  final String price;
  final String rating;

  SellerItem({
    required this.name,
    required this.image,
    required this.price,
    required this.rating,
  });
}

final List<SellerItem> sellerItems = [
  SellerItem(
    name: "Kufri Bahar",
    image: "assets/seller_listing_p.png",
    price: "40",
    rating: "4.5",
  ),
  SellerItem(
    name: "Kufri Jyoti",
    image: "assets/seller_listing_p.png",
    price: "25",
    rating: "4.2",
  ),
  SellerItem(
    name: "Kufri Pukhraj",
    image: "assets/seller_listing_p.png",
    price: "30",
    rating: "4.3",
  ),
  SellerItem(
    name: "Kufri Ganga",
    image: "assets/seller_listing_p.png",
    price: "45",
    rating: "4.5",
  ),
];
