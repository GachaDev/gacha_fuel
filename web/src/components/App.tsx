import { useEffect, useState } from "react";
import {debugData} from "../utils/debugData";
import { FaGasPump } from 'react-icons/fa';
import { useNuiEvent } from "../hooks/useNuiEvent";
import { fetchNui } from "../utils/fetchNui";

// This will set the NUI to visible if we are
// developing in browser
debugData([
    {
        action: 'setVisible',
        data: true,
    }
])

interface data {
    Total: string;
    Title: string;
    SetAmount: string;
    Buy: string;
}

const App: React.FC = () => {
    const [litres, setLitres] = useState(0);
    const [actFuel, setActFuel] = useState(30);
    const maxFuel = 100;
    const [titleLabel, setTitleLabel] = useState('GAS STATION');
    const [totalLabel, setTotalLabel] = useState('TOTAL');
    const [amountLabel, setAmountLabel] = useState('SET AMOUNT');
    const [buyLabel, setBuyLabel] = useState('BUY FUEL');
    const [litrePrice, setLitrePrice] = useState(1);
    const fuelSound = new Audio('https://cdn.discordapp.com/attachments/919641744704954461/1145065049484963922/fuel-sound.mp3')

    const loadActFuel = (fuel: number) => {
        setActFuel(fuel);
    }

    const loadPriceLitre = (price: number) => {
        setLitrePrice(price);
    }

    const stopSound = () => {
        fuelSound.pause()
    }

    useNuiEvent<number>('loadActFuel', loadActFuel);
    useNuiEvent<number>('loadPriceLitre', loadPriceLitre);
    useNuiEvent('stopSound', stopSound);

    const changeLitres = (n: number) => {
        if (n > (maxFuel - actFuel)) {
            setLitres(maxFuel - actFuel);
        } else {
            if (n < 0) {
                setLitres(0);
            } else {
                setLitres(n);
            }
        }
    }

    const checkMoney = async () => {
        try {
            const res = await fetchNui<Boolean>('checkMoney', litres);
            if (res) {
                fuelSound.volume = 0.5
                fuelSound.play()
                console.log('tiene suficiente dinero')
            }
        } catch (e) {
            console.error(e);
        }
    }

    const LoadTranslations = async () => {
        try {
            const res = await fetchNui<data>('LoadTranslations');
            setTitleLabel(res.Title);
            setTotalLabel(res.Total);
            setAmountLabel(res.SetAmount);
            setBuyLabel(res.Buy);
        } catch (e) {
            console.error(e);
        }
    }

    useEffect(()=> {
        LoadTranslations()
    }, [])

    return (
        <div className="container">
            <div className="title">
                <div className="contTitle">
                    <FaGasPump size={'2.5vw'} /> {titleLabel}
                </div>
            </div>
            <div className="progress">
                <div className="bar">
                    <div className="actBar" style={{height:actFuel+'%'}} />
                    <div className="newBar" style={{height:(litres | 0)+'%'}} />
                </div>
                <div className="amount">
                    <div className="titleAmount">
                        {amountLabel}
                    </div>
                    <div>
                        <input className="inputL" type="number" max={100} min={1} onChange={(event) => changeLitres(event.target.valueAsNumber)} value={litres.toString()} />
                        <span className="litres">L</span>
                    </div>
                </div>
            </div>
            <div className="totalMoney">
                <span className="totalTitle">
                    {totalLabel}
                </span>
                <span className="price">
                    ${(litres * litrePrice) | 0}
                </span>
            </div>
            <button className="buyButton" onClick={()=>{checkMoney()}}>
                {buyLabel}
            </button>
        </div>
    );
}

export default App;