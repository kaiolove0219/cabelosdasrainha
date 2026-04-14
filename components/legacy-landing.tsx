"use client";

import { useEffect, useRef } from "react";
import { DevelopmentStackBadge } from "./development-stack-badge";

const CHECKOUT_URL = "https://pay.risepay.com.br/Pay/c2674711f5b8498fba0bf252e32ad5db";

type LegacyLandingProps = {
  html: string;
};

export function LegacyLanding({ html }: LegacyLandingProps) {
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const root = rootRef.current;

    if (!root) {
      return;
    }

    const disposers: Array<() => void> = [];
    const intervals: number[] = [];
    const galleryButtons = Array.from(root.querySelectorAll<HTMLButtonElement>(".thumb"));
    const mainImage = root.querySelector<HTMLImageElement>("#mainImage");
    const accordionItems = Array.from(root.querySelectorAll<HTMLElement>(".accordion-item"));
    const checkoutLinks = Array.from(
      root.querySelectorAll<HTMLAnchorElement>("[data-checkout-link='true']"),
    );
    const countdownTimer = root.querySelector<HTMLElement>("#countdownTimer");
    const liveBuyers = root.querySelector<HTMLElement>("#liveBuyers");

    checkoutLinks.forEach((link) => {
      link.setAttribute("href", CHECKOUT_URL);
    });

    if (mainImage) {
      galleryButtons.forEach((button) => {
        const handleClick = () => {
          const nextImage = button.dataset.image;
          const nextAlt = button.dataset.alt;

          if (nextImage) {
            mainImage.src = nextImage;
          }

          if (nextAlt) {
            mainImage.alt = nextAlt;
          }

          galleryButtons.forEach((item) => item.classList.remove("active"));
          button.classList.add("active");
        };

        button.addEventListener("click", handleClick);
        disposers.push(() => button.removeEventListener("click", handleClick));
      });
    }

    accordionItems.forEach((item) => {
      const trigger = item.querySelector<HTMLButtonElement>(".accordion-header");

      if (!trigger) {
        return;
      }

      const handleClick = () => {
        const isOpen = item.classList.contains("open");

        accordionItems.forEach((otherItem) => {
          otherItem.classList.remove("open");
          otherItem
            .querySelector<HTMLButtonElement>(".accordion-header")
            ?.setAttribute("aria-expanded", "false");
        });

        if (!isOpen) {
          item.classList.add("open");
          trigger.setAttribute("aria-expanded", "true");
        }
      };

      trigger.addEventListener("click", handleClick);
      disposers.push(() => trigger.removeEventListener("click", handleClick));
    });

    if (countdownTimer) {
      const countdownDuration = 15 * 60;
      let timeLeft = countdownDuration;

      const renderCountdown = () => {
        const minutes = Math.floor(timeLeft / 60);
        const seconds = timeLeft % 60;
        countdownTimer.textContent = `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(
          2,
          "0",
        )}`;
      };

      renderCountdown();

      const countdownInterval = window.setInterval(() => {
        timeLeft = timeLeft > 1 ? timeLeft - 1 : countdownDuration;
        renderCountdown();
      }, 1000);

      intervals.push(countdownInterval);
    }

    if (liveBuyers) {
      const startingBuyers = 23;
      const maxBuyers = 200;
      let buyersNow = startingBuyers;

      liveBuyers.textContent = String(buyersNow);

      const buyersInterval = window.setInterval(() => {
        if (buyersNow < maxBuyers) {
          buyersNow += 1;
          liveBuyers.textContent = String(buyersNow);
        }
      }, 20000);

      intervals.push(buyersInterval);
    }

    return () => {
      disposers.forEach((dispose) => dispose());
      intervals.forEach((interval) => window.clearInterval(interval));
    };
  }, [html]);

  return (
    <>
      <div ref={rootRef} dangerouslySetInnerHTML={{ __html: html }} />
      <DevelopmentStackBadge />
    </>
  );
}

