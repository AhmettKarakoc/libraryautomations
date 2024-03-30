import List "mo:base/List";
import Option "mo:base/Option";
import Trie "mo:base/Trie";
import Nat32 "mo:base/Nat32";
import Map "mo:base/HashMap";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Text "mo:base/Text";

actor LibraryAutomation {

    /**
     * Types
     */

    // Kitap tanımı
    public type Book = {
        title : Text;
        author : Text;
        genre : Text;
        available : Bool;
    };

    // Kitap kimlik numarası
    public type BookId = Nat32;

    // Kullanıcı tanımı
    public type User = {
        name : Text;
        borrowedBooks : List<BookId>;
    };

    // Kullanıcı kimlik numarası
    public type UserId = Nat32;

    /**
     * Application State
     */

    // Sonraki kullanıcı kimlik numarası
    private stable var nextUserId : UserId = 0;

    // Kullanıcı veri deposu
    private stable var users : Map.Map<UserId, User> = Map.empty();

    // Sonraki kitap kimlik numarası
    private stable var nextBookId : BookId = 0;

    // Kitap veri deposu
    private stable var books : Map.Map<BookId, Book> = Map.empty();

    /**
     * High-Level API
     */

    // Kitap ekleme metodu
    public func addBook(book : Book) : async BookId {
        let bookId = nextBookId;
        nextBookId += 1;
        books := Map.insert(books, bookId, book);
        return bookId;
    };

    // Kitapların listelenmesi
    public query func getAllBooks() : async List<Book> {
        return Iter.toList(books.entries);
    };

    // Üyelerin kitap satın alması
    public func borrowBook(userId : UserId, bookId : BookId) : async Bool {
        // Kullanıcıyı bul
        let user = Map.get(users, userId);
        if (Option.isNone(user)) {
            return false; // Kullanıcı bulunamadı
        };

        // Kitabı bul
        let book = Map.get(books, bookId);
        if (Option.isNone(book)) {
            return false; // Kitap bulunamadı
        };

        // Kullanıcı zaten bu kitabı ödünç almış mı?
        if (List.contains<BookId>(user.borrowedBooks, bookId)) {
            return false; // Kullanıcı bu kitabı zaten ödünç almış
        };

        // Kitap mevcut mu?
        if (book.available) {
            return false; // Kitap mevcut değil
        };

        // Kullanıcının kitabı ödünç alması
        users := Map.update(users, userId, func(optUser) {
            switch (optUser) {
                case (null) { return null; };
                case (?u) {
                    return ?{ u with borrowedBooks = List.cons<BookId>(bookId, u.borrowedBooks) };
                };
            };
        });

        // Kitabın durumunu güncelle
        books := Map.update(books, bookId, func(optBook) {
            switch (optBook) {
                case (null) { return null; };
                case (?b) {
                    return ?{ b with available = false };
                };
            };
        });

        return true; // İşlem başarılı
    };

    // Kitap silme metodu
    public func deleteBook(bookId : BookId) : async Bool {
        // Kitabı bul
        let book = Map.get(books, bookId);
        if (Option.isNone(book)) {
            return false; // Kitap bulunamadı
        };

        // Kitabı veri deposundan kaldır
        books := Map.remove(books, bookId);

        // Kitabı ödünç alan tüm kullanıcıların listesinden kaldır
        for (user in Iter.toList(users.values)) {
            users := Map.update(users, user.id, func(optUser) {
                switch (optUser) {
                    case (null) { return null; };
                    case (?u) {
                        return ?{ u with borrowedBooks = List.filter((bookId_) >= bookId_ != bookId, u.borrowedBooks) };
                    };
                };
            });
        };

        return true; // İşlem başarılı
    };
};
