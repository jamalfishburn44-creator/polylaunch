// ==========================================================
// PolyLaunch v2
// app.js
// ==========================================================

document.addEventListener("DOMContentLoaded", () => {

    console.log("PolyLaunch Loaded");

    // Wallet Button

    const walletButtons = document.querySelectorAll(
        ".wallet-button"
    );

    walletButtons.forEach(button => {

        button.addEventListener("click", () => {

            alert(
                "Wallet connection coming soon."
            );

        });

    });

    // Primary Buttons

    document.querySelectorAll(
        ".primary-button"
    ).forEach(button => {

        button.addEventListener("mouseenter", () => {

            button.style.transform = "translateY(-2px)";

        });

        button.addEventListener("mouseleave", () => {

            button.style.transform = "";

        });

    });

    // Card Hover Animation

    document.querySelectorAll(
        ".project-card"
    ).forEach(card => {

        card.addEventListener("mouseenter", () => {

            card.style.transition = "0.3s";

        });

    });

});
