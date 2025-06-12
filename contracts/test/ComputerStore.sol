pragma solidity =0.5.16;

import '../libraries/SafeMath.sol';

contract ComputerStore {
    using SafeMath for uint;

    address public owner;
    
    struct Computer {
        uint id;
        string model;
        string brand;
        string specs;
        uint price;
        uint stock;
        bool available;
    }
    
    struct Sale {
        uint id;
        address customer;
        uint computerId;
        uint price;
        uint date;
        bool hasWarranty;
        uint warrantyEndDate;
    }
    
    struct Customer {
        address customerAddress;
        uint loyaltyPoints;
        uint totalPurchases;
        bool isPremium;
    }
    
    mapping(uint => Computer) public computers;
    mapping(uint => Sale) public sales;
    mapping(address => Customer) public customers;
    
    uint public computerCount;
    uint public saleCount;
    uint public revenue;
    
    event ComputerAdded(uint id, string model, string brand, uint price);
    event StockUpdated(uint computerId, uint newStock);
    event ComputerSold(uint saleId, uint computerId, address customer, uint price);
    event WarrantyExtended(uint saleId, uint newEndDate);
    event CustomerUpgraded(address customer, bool isPremium);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el propietario puede ejecutar esta función");
        _;
    }
    
    constructor() public {
        owner = msg.sender;
        computerCount = 0;
        saleCount = 0;
        revenue = 0;
    }
    
    function addComputer(
        string memory _model,
        string memory _brand, 
        string memory _specs,
        uint _price, 
        uint _stock
    ) 
        public 
        onlyOwner 
        returns (uint)
    {
        computerCount = computerCount.add(1);
        computers[computerCount] = Computer(
            computerCount,
            _model,
            _brand,
            _specs,
            _price,
            _stock,
            true
        );
        
        emit ComputerAdded(computerCount, _model, _brand, _price);
        return computerCount;
    }
    
    function updateStock(uint _computerId, uint _newStock) public onlyOwner {
        require(_computerId > 0 && _computerId <= computerCount, "ID de computadora no válido");
        computers[_computerId].stock = _newStock;
        if (_newStock == 0) {
            computers[_computerId].available = false;
        } else {
            computers[_computerId].available = true;
        }
        
        emit StockUpdated(_computerId, _newStock);
    }
    
    function buyComputer(uint _computerId) public payable returns (uint) {
        Computer storage computer = computers[_computerId];
        require(computer.id > 0, "Computadora no encontrada");
        require(computer.available, "Computadora no disponible");
        require(computer.stock > 0, "Computadora sin stock");
        require(msg.value >= computer.price, "Fondos insuficientes");
        
        // Actualizar stock
        computer.stock = computer.stock.sub(1);
        if (computer.stock == 0) {
            computer.available = false;
        }
        
        // Registrar venta
        saleCount = saleCount.add(1);
        uint warrantyEnd = now + 365 days; // Garantía de 1 año
        sales[saleCount] = Sale(
            saleCount,
            msg.sender,
            _computerId,
            computer.price,
            now,
            true,
            warrantyEnd
        );
        
        // Actualizar datos del cliente
        if (customers[msg.sender].customerAddress == address(0)) {
            customers[msg.sender] = Customer(msg.sender, 10, 1, false);
        } else {
            Customer storage customer = customers[msg.sender];
            customer.loyaltyPoints = customer.loyaltyPoints.add(10);
            customer.totalPurchases = customer.totalPurchases.add(1);
            
            // Actualizar a cliente premium si tiene más de 5 compras
            if (customer.totalPurchases >= 5 && !customer.isPremium) {
                customer.isPremium = true;
                emit CustomerUpgraded(msg.sender, true);
            }
        }
        
        // Actualizar ingresos
        revenue = revenue.add(computer.price);
        
        // Si el cliente pagó de más, devolver el cambio
        if (msg.value > computer.price) {
            msg.sender.transfer(msg.value.sub(computer.price));
        }
        
        emit ComputerSold(saleCount, _computerId, msg.sender, computer.price);
        return saleCount;
    }
    
    function extendWarranty(uint _saleId) public payable {
        Sale storage sale = sales[_saleId];
        require(sale.id > 0, "Venta no encontrada");
        require(sale.customer == msg.sender, "Solo el dueño puede extender la garantía");
        require(sale.hasWarranty, "La venta no tiene garantía");
        require(sale.warrantyEndDate > now, "La garantía ha expirado");
        
        uint extensionFee;
        Computer storage computer = computers[sale.computerId];
        extensionFee = computer.price.div(10); // 10% del precio para extender
        
        require(msg.value >= extensionFee, "Fondos insuficientes para extender la garantía");
        
        // Extender garantía por 6 meses adicionales
        sale.warrantyEndDate = sale.warrantyEndDate.add(180 days);
        
        // Actualizar ingresos
        revenue = revenue.add(extensionFee);
        
        // Devolver cambio si hay
        if (msg.value > extensionFee) {
            msg.sender.transfer(msg.value.sub(extensionFee));
        }
        
        emit WarrantyExtended(_saleId, sale.warrantyEndDate);
    }
    
    function checkWarranty(uint _saleId) public view returns (bool isValid, uint endDate) {
        Sale storage sale = sales[_saleId];
        require(sale.id > 0, "Venta no encontrada");
        
        isValid = (sale.hasWarranty && sale.warrantyEndDate > now);
        endDate = sale.warrantyEndDate;
    }
    
    function getComputerDetails(uint _computerId) public view returns (
        string memory model,
        string memory brand,
        string memory specs,
        uint price,
        uint stock,
        bool available
    ) {
        Computer storage computer = computers[_computerId];
        require(computer.id > 0, "Computadora no encontrada");
        
        return (
            computer.model,
            computer.brand,
            computer.specs,
            computer.price,
            computer.stock,
            computer.available
        );
    }
    
    function getCustomerInfo(address _customerAddress) public view returns (
        uint loyaltyPoints,
        uint totalPurchases,
        bool isPremium
    ) {
        Customer storage customer = customers[_customerAddress];
        require(customer.customerAddress != address(0), "Cliente no encontrado");
        
        return (
            customer.loyaltyPoints,
            customer.totalPurchases,
            customer.isPremium
        );
    }
    
    function withdrawFunds() public onlyOwner {
        uint amount = address(this).balance;
        owner.transfer(amount);
    }
    
    function changeOwner(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Dirección inválida");
        owner = _newOwner;
    }
    
    // Función para recibir ETH
    function() external payable {}
}
