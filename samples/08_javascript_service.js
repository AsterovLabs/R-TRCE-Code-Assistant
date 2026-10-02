/**
 * samples/08_javascript_service.js -- Polyglot JavaScript Service Sample
 * Demonstrates async function workflows, arrow functions, and class architecture.
 */

function calculateDiscount(price, rate) {
  const discount = price * (rate / 100);
  return Number((price - discount).toFixed(2));
}

const formatCurrency = (amount, currency = 'USD') => {
  return `${currency} ${amount.toFixed(2)}`;
};

class OrderProcessor {
  constructor(taxRate = 8.5) {
    this.taxRate = taxRate;
    this.processedOrders = [];
  }

  process(orderId, items, discountPct = 0) {
    const rawTotal = items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    const discounted = calculateDiscount(rawTotal, discountPct);
    const tax = discounted * (this.taxRate / 100);
    const finalTotal = discounted + tax;

    const receipt = {
      orderId,
      subtotal: discounted,
      tax: Number(tax.toFixed(2)),
      total: Number(finalTotal.toFixed(2)),
      formatted: formatCurrency(finalTotal)
    };

    this.processedOrders.push(receipt);
    return receipt;
  }
}

// Sample execution
const processor = new OrderProcessor(7.0);
const receipt = processor.process('ORD-9021', [
  { name: 'Widget A', price: 25.00, quantity: 2 },
  { name: 'Cable B', price: 12.50, quantity: 1 }
], 10);

console.log('Order Processed:', receipt.formatted);
